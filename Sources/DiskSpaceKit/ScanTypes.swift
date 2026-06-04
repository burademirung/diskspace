import Foundation

// ByteCountFormatter is safe to share: created once, string(fromByteCount:) is effectively read-only.
nonisolated(unsafe) private let sharedSizeFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter
}()

// Shared, single-creation date formatter (DateFormatter is Sendable).
private let sharedDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
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

    public var formattedDate: String {
        modificationDate == .distantPast ? "" : sharedDateFormatter.string(from: modificationDate)
    }

    public var displayPath: String {
        DiskSpaceKit.displayPath(for: url)
    }
}

public struct FolderItem: Sendable {
    public let url: URL
    public let totalSize: Int64
    public let itemCount: Int
    public let modificationDate: Date

    public init(url: URL, totalSize: Int64, itemCount: Int, modificationDate: Date = .distantPast) {
        self.url = url
        self.totalSize = totalSize
        self.itemCount = itemCount
        self.modificationDate = modificationDate
    }

    public var formattedSize: String {
        sharedSizeFormatter.string(fromByteCount: totalSize)
    }

    public var formattedDate: String {
        modificationDate == .distantPast ? "" : sharedDateFormatter.string(from: modificationDate)
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
