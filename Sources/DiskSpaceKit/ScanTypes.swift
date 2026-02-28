import Foundation

public struct FileItem: Sendable {
    public let url: URL
    public let size: Int64
    public let modificationDate: Date

    public init(url: URL, size: Int64, modificationDate: Date) {
        self.url = url
        self.size = size
        self.modificationDate = modificationDate
    }

    nonisolated(unsafe) private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    public var formattedSize: String {
        Self.formatter.string(fromByteCount: size)
    }

    public var displayPath: String {
        let home = NSHomeDirectory()
        let path = url.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
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

    nonisolated(unsafe) private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    public var formattedSize: String {
        Self.formatter.string(fromByteCount: totalSize)
    }

    public var displayPath: String {
        let home = NSHomeDirectory()
        let path = url.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
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
