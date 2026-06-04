import Foundation
import AppKit

/// Running totals accumulated for a directory during a scan.
private struct FolderAccumulator {
    var size: Int64 = 0
    var count: Int = 0
    var date: Date = .distantPast
}

@MainActor
public final class DiskScanner {

    public private(set) var largeFiles: [FileItem] = []
    public private(set) var largeFolders: [FolderItem] = []
    public private(set) var scanState: ScanState = .idle
    public private(set) var minimumFileSize: Int64 = 50_000_000 // 50 MB

    /// The minimum file size the current results were collected at. Lowering
    /// the UI threshold below this requires a fresh scan, since smaller files
    /// were never gathered. 0 means no scan has run yet.
    public private(set) var scannedThreshold: Int64 = 0

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
        scannedThreshold = threshold

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
                func isDeletedOrDescendant(_ path: String) -> Bool {
                    deletedPaths.contains(path)
                        || deletedPaths.contains { path.hasPrefix($0 + "/") }
                }
                // Drop deleted items and any descendants of deleted folders.
                // Surviving ancestor folder totals stay approximate until the
                // next scan.
                self.largeFiles.removeAll { isDeletedOrDescendant($0.url.path) }
                self.largeFolders.removeAll { isDeletedOrDescendant($0.url.path) }
                self.onUpdate?()
            }
        }
    }

    // MARK: - Scanning (runs off MainActor)

    // Keys requested from the enumerator. Declared once so the same set is
    // reused for both enumerator-init and per-URL resourceValues calls.
    nonisolated private static let resourceKeys: Set<URLResourceKey> = [
        .totalFileAllocatedSizeKey,
        .fileSizeKey,
        .isDirectoryKey,
        .isRegularFileKey,
        .contentModificationDateKey
    ]

    // Paths skipped during scan (other volumes, device nodes, VM swap).
    nonisolated private static let skipPrefixes = ["/Volumes/", "/dev/", "/private/var/vm/"]

    nonisolated private static func performScan(
        root: URL,
        threshold: Int64,
        continuation: AsyncStream<ScanUpdate>.Continuation
    ) {
        let resolvedRoot = resolveSymlinks(root)
        let rootPath = resolvedRoot.path

        guard let enumerator = FileManager.default.enumerator(
            at: resolvedRoot,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [],
            errorHandler: { _, _ in true } // skip errors, keep going
        ) else {
            continuation.finish()
            return
        }

        var files: [FileItem] = []
        var folderSizes: [String: FolderAccumulator] = [:]
        var scannedCount = 0

        // Skip other volumes / device nodes / VM swap only on a whole-disk scan;
        // a scoped scan (Home, a chosen folder, an external volume) scans fully.
        let applySystemSkips = (rootPath == "/")

        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }

            if applySystemSkips, skipPrefixes.contains(where: { fileURL.path.hasPrefix($0) }) {
                enumerator.skipDescendants()
                continue
            }

            processEntry(
                fileURL: fileURL,
                rootPath: rootPath,
                threshold: threshold,
                files: &files,
                folderSizes: &folderSizes
            )

            scannedCount += 1
            if scannedCount.isMultiple(of: 1000) {
                continuation.yield(.progress(scannedCount: scannedCount))
            }
        }

        guard !Task.isCancelled else {
            continuation.finish()
            return
        }

        emitResults(files: files, folderSizes: folderSizes, continuation: continuation)
    }

    /// Resolve symlinks (e.g., /var -> /private/var) so paths from
    /// `FileManager.enumerator` match the root path consistently.
    nonisolated private static func resolveSymlinks(_ url: URL) -> URL {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard let resolvedPath = realpath(url.path, &buffer) else { return url }
        return URL(fileURLWithPath: String(cString: resolvedPath))
    }

    nonisolated private static func processEntry(
        fileURL: URL,
        rootPath: String,
        threshold: Int64,
        files: inout [FileItem],
        folderSizes: inout [String: FolderAccumulator]
    ) {
        guard let values = try? fileURL.resourceValues(forKeys: resourceKeys),
              values.isRegularFile == true else { return }

        // Prefer allocated size (actual disk usage) over logical size.
        let fileSize = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        guard fileSize > 0 else { return }

        let modificationDate = values.contentModificationDate ?? .distantPast

        accumulateFolderSizes(
            for: fileURL,
            fileSize: fileSize,
            modificationDate: modificationDate,
            rootPath: rootPath,
            into: &folderSizes
        )

        if fileSize >= threshold {
            files.append(FileItem(url: fileURL, size: fileSize, modificationDate: modificationDate))
        }
    }

    /// Add `fileSize` to every ancestor directory of `fileURL` up to `rootPath`.
    nonisolated private static func accumulateFolderSizes(
        for fileURL: URL,
        fileSize: Int64,
        modificationDate: Date,
        rootPath: String,
        into folderSizes: inout [String: FolderAccumulator]
    ) {
        // Match on a path-boundary ("rootPath/") so a sibling like
        // "/x/foobar" is not mistaken for a child of root "/x/foo".
        let rootBoundary = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        var dirPath = fileURL.deletingLastPathComponent().path
        while dirPath == rootPath || dirPath.hasPrefix(rootBoundary) {
            var entry = folderSizes[dirPath, default: FolderAccumulator()]
            entry.size += fileSize
            entry.count += 1
            if modificationDate > entry.date { entry.date = modificationDate }
            folderSizes[dirPath] = entry
            if dirPath == rootPath { break } // don't ascend past the scan root
            let parent = (dirPath as NSString).deletingLastPathComponent
            if parent == dirPath { break }
            dirPath = parent
        }
    }

    nonisolated private static func emitResults(
        files: [FileItem],
        folderSizes: [String: FolderAccumulator],
        continuation: AsyncStream<ScanUpdate>.Continuation
    ) {
        let sortedFiles = files.sorted { $0.size > $1.size }
        let folders = folderSizes
            .map { FolderItem(
                url: URL(fileURLWithPath: $0.key),
                totalSize: $0.value.size,
                itemCount: $0.value.count,
                modificationDate: $0.value.date
            )}
            .sorted { $0.totalSize > $1.totalSize }
            .prefix(500)

        continuation.yield(.completed(files: sortedFiles, folders: Array(folders)))
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
