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
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useGB, .useTB]
        return f
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
        let url = URL(fileURLWithPath: "/")
        let values = try url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ])
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        let total = Int64(values.volumeTotalCapacity ?? 0)
        return DiskInfo(totalBytes: total, availableBytes: available)
    }

    public static func volumeName() throws -> String {
        let url = URL(fileURLWithPath: "/")
        let values = try url.resourceValues(forKeys: [.volumeNameKey])
        return values.volumeName ?? "Macintosh HD"
    }
}
