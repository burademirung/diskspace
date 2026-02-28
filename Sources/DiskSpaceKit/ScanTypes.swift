import Foundation

// ByteCountFormatter is safe to share: created once, string(fromByteCount:) is effectively read-only.
nonisolated(unsafe) private let sharedSizeFormatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.countStyle = .file
    return f
}()

private func displayPath(for url: URL) -> String {
    let home = NSHomeDirectory()
    let path = url.path
    if path.hasPrefix(home) {
        return "~" + path.dropFirst(home.count)
    }
    return path
}

public struct FileItem: Sendable {
    public let url: URL
    public let size: Int64
    public let modificationDate: Date

    public init(url: URL, size: Int64, modificationDate: Date) {
        self.url = url
        self.size = size
        self.modificationDate = modificationDate
    }

    public var formattedSize: String {
        sharedSizeFormatter.string(fromByteCount: size)
    }

    public var displayPath: String {
        DiskSpaceKit.displayPath(for: url)
    }
}

public struct FolderItem: Sendable {
    public let url: URL
    public let totalSize: Int64
    public let itemCount: Int

    public init(url: URL, totalSize: Int64, itemCount: Int) {
        self.url = url
        self.totalSize = totalSize
        self.itemCount = itemCount
    }

    public var formattedSize: String {
        sharedSizeFormatter.string(fromByteCount: totalSize)
    }

    public var displayPath: String {
        DiskSpaceKit.displayPath(for: url)
    }
}

public enum ScanState: Sendable {
    case idle
    case scanning(scannedCount: Int)
    case done(fileCount: Int, folderCount: Int)
}

public enum ScanUpdate: Sendable {
    case progress(scannedCount: Int)
    case completed(files: [FileItem], folders: [FolderItem])
}
