import Foundation
import AppKit

@MainActor
public final class DiskScanner {

    public private(set) var largeFiles: [FileItem] = []
    public private(set) var largeFolders: [FolderItem] = []
    public private(set) var scanState: ScanState = .idle
    public private(set) var minimumFileSize: Int64 = 50_000_000 // 50 MB

    public var onUpdate: (@MainActor () -> Void)?

    private var scanTask: Task<Void, Never>?

    public init() {}

    public func setMinimumFileSize(_ size: Int64) {
        minimumFileSize = size
    }

    public func startScan(rootURL: URL = URL(fileURLWithPath: "/")) {
        cancel()
        largeFiles = []
        largeFolders = []
        scanState = .scanning(scannedCount: 0)
        onUpdate?()

        let threshold = minimumFileSize

        scanTask = Task {
            let stream = AsyncStream<ScanUpdate> { continuation in
                let scanWork = Task.detached {
                    Self.performScan(
                        root: rootURL,
                        threshold: threshold,
                        continuation: continuation
                    )
                }
                continuation.onTermination = { @Sendable _ in
                    scanWork.cancel()
                }
            }

            for await update in stream {
                if Task.isCancelled { break }
                switch update {
                case .progress(let count):
                    self.scanState = .scanning(scannedCount: count)
                case .completed(let files, let folders):
                    self.largeFiles = files
                    self.largeFolders = folders
                    self.scanState = .done(
                        fileCount: files.count,
                        folderCount: folders.count
                    )
                }
                self.onUpdate?()
            }

            if Task.isCancelled {
                self.scanState = .idle
                self.onUpdate?()
            }
        }
    }

    public func cancel() {
        scanTask?.cancel()
        scanTask = nil
    }

    public func deleteItems(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.recycle(urls) { [weak self] _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    NSLog("Failed to recycle: \(error)")
                    return
                }
                let deletedPaths = Set(urls.map(\.path))
                self.largeFiles.removeAll { deletedPaths.contains($0.url.path) }
                self.largeFolders.removeAll { deletedPaths.contains($0.url.path) }
                self.onUpdate?()
            }
        }
    }

    // MARK: - Scanning (runs off MainActor)

    nonisolated private static func performScan(
        root: URL,
        threshold: Int64,
        continuation: AsyncStream<ScanUpdate>.Continuation
    ) {
        let fm = FileManager.default

        // Resolve symlinks (e.g., /var -> /private/var) so paths from
        // FileManager.enumerator match the root path consistently.
        let root: URL = {
            var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
            guard let rp = realpath(root.path, &buf) else { return root }
            return URL(fileURLWithPath: String(cString: rp))
        }()
        let keys: Set<URLResourceKey> = [
            .fileSizeKey,
            .isDirectoryKey,
            .isRegularFileKey,
            .contentModificationDateKey
        ]

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true } // skip errors, keep going
        ) else {
            continuation.finish()
            return
        }

        var files: [FileItem] = []
        var folderSizes: [String: (size: Int64, count: Int)] = [:]
        var scannedCount = 0

        // Paths to skip (avoid other volumes, device nodes, VM swap)
        let skipPrefixes = ["/Volumes/", "/dev/", "/private/var/vm/"]

        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }

            let path = fileURL.path

            // Skip special system paths
            if skipPrefixes.contains(where: { path.hasPrefix($0) }) {
                enumerator.skipDescendants()
                continue
            }

            guard let values = try? fileURL.resourceValues(forKeys: keys) else {
                continue
            }

            let isRegular = values.isRegularFile ?? false
            let fileSize = Int64(values.fileSize ?? 0)

            if isRegular && fileSize > 0 {
                // Accumulate size to this file's directory and all ancestors
                var dirPath = fileURL.deletingLastPathComponent().path
                while !dirPath.isEmpty {
                    var entry = folderSizes[dirPath, default: (size: 0, count: 0)]
                    entry.size += fileSize
                    entry.count += 1
                    folderSizes[dirPath] = entry
                    let parent = (dirPath as NSString).deletingLastPathComponent
                    if parent == dirPath { break }
                    dirPath = parent
                }

                // Collect large files
                if fileSize >= threshold {
                    files.append(FileItem(
                        url: fileURL,
                        size: fileSize,
                        modificationDate: values.contentModificationDate ?? .distantPast
                    ))
                }
            }

            scannedCount += 1
            if scannedCount % 1000 == 0 {
                continuation.yield(.progress(scannedCount: scannedCount))
            }
        }

        guard !Task.isCancelled else {
            continuation.finish()
            return
        }

        // Sort results
        files.sort { $0.size > $1.size }

        let folders = folderSizes
            .map { FolderItem(
                url: URL(fileURLWithPath: $0.key),
                totalSize: $0.value.size,
                itemCount: $0.value.count
            )}
            .sorted { $0.totalSize > $1.totalSize }
            .prefix(500)

        continuation.yield(.completed(files: files, folders: Array(folders)))
        continuation.finish()
    }
}

// MARK: - ScanState helpers

extension ScanState {
    public var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}
