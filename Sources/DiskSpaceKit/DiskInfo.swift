import Foundation

public enum BarColor: Sendable {
    case green, yellow, red
}

public struct DiskInfo: Sendable {
    public let totalBytes: Int64
    public let availableBytes: Int64

    public init(totalBytes: Int64, availableBytes: Int64) {
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
    }

    public var freeBytes: Int64 { availableBytes }
    public var usedBytes: Int64 { totalBytes - availableBytes }

    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    public var freeFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeBytes) / Double(totalBytes)
    }

    public var barColor: BarColor {
        if freeFraction < 0.10 { return .red }
        if freeFraction < 0.20 { return .yellow }
        return .green
    }

    private nonisolated(unsafe) static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useTB]
        return formatter
    }()

    public var formattedFree: String {
        Self.formatter.string(fromByteCount: freeBytes)
    }

    public var formattedUsed: String {
        Self.formatter.string(fromByteCount: usedBytes)
    }

    public var formattedTotal: String {
        Self.formatter.string(fromByteCount: totalBytes)
    }

    public static func readBootVolume() throws -> DiskInfo {
        try readVolume(at: URL(fileURLWithPath: "/"))
    }

    public static func readVolume(at url: URL) throws -> DiskInfo {
        let values = try url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ])
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        let total = Int64(values.volumeTotalCapacity ?? 0)
        return DiskInfo(totalBytes: total, availableBytes: available)
    }

    public static func volumeName() throws -> String {
        try volumeName(at: URL(fileURLWithPath: "/"))
    }

    public static func volumeName(at url: URL) throws -> String {
        let values = try url.resourceValues(forKeys: [.volumeNameKey])
        return values.volumeName ?? "Macintosh HD"
    }
}

/// A mounted, user-browsable volume the app can monitor and scan.
public struct VolumeInfo: Sendable, Identifiable {
    public let url: URL
    public let name: String

    public var id: String { url.path }

    public init(url: URL, name: String) {
        self.url = url
        self.name = name
    }
}

extension DiskInfo {
    /// All mounted, browsable, non-empty volumes (boot volume + externals).
    public static func mountedVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeIsBrowsableKey, .volumeTotalCapacityKey
        ]
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.volumeIsBrowsable == true,
                  (values.volumeTotalCapacity ?? 0) > 0 else { return nil }
            return VolumeInfo(url: url, name: values.volumeName ?? url.lastPathComponent)
        }
    }
}
