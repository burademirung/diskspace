import Foundation

/// A well-known location that commonly accumulates reclaimable space.
public struct CleanupTarget: Sendable, Identifiable {
    public let name: String
    public let url: URL
    public let detail: String
    /// Permanent: emptying the Trash cannot be undone. Other targets move their
    /// contents to the Trash (recoverable).
    public let isPermanent: Bool

    public var id: String { url.path }

    public init(name: String, url: URL, detail: String, isPermanent: Bool) {
        self.name = name
        self.url = url
        self.detail = detail
        self.isPermanent = isPermanent
    }
}

/// A cleanup target paired with its (lazily computed) size for display.
public struct CleanupRow {
    public let target: CleanupTarget
    public var size: Int64

    public init(target: CleanupTarget, size: Int64) {
        self.target = target
        self.size = size
    }
}

public enum Cleanup {

    /// Standard reclaimable locations that exist on this machine.
    public static func standardTargets() -> [CleanupTarget] {
        let home = FileManager.default.homeDirectoryForCurrentUser

        func target(_ name: String, _ relative: String, _ detail: String, permanent: Bool) -> CleanupTarget? {
            let url = home.appendingPathComponent(relative)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return CleanupTarget(name: name, url: url, detail: detail, isPermanent: permanent)
        }

        return [
            target("User Caches", "Library/Caches",
                   "App caches — apps rebuild these as needed", permanent: false),
            target("Xcode DerivedData", "Library/Developer/Xcode/DerivedData",
                   "Xcode build intermediates", permanent: false),
            target("Xcode iOS DeviceSupport", "Library/Developer/Xcode/iOS DeviceSupport",
                   "Debug symbols for connected iOS devices", permanent: false),
            target("CoreSimulator Caches", "Library/Developer/CoreSimulator/Caches",
                   "Simulator runtime caches", permanent: false),
            target("Trash", ".Trash",
                   "Items in the Trash — emptying is permanent", permanent: true)
        ].compactMap { $0 }
    }

    /// Recursively sum allocated sizes under `url`. Runs off the main actor.
    public static func directorySize(_ url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    /// The immediate children of `url` (the items moved to Trash when cleaning
    /// a non-permanent target — we keep the parent directory itself).
    public static func contents(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil
        )) ?? []
    }

    /// Permanently delete everything inside the Trash.
    public static func emptyTrash() throws {
        let trash = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash")
        for item in contents(of: trash) {
            try FileManager.default.removeItem(at: item)
        }
    }
}
