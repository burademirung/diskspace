import Foundation

/// What the menu-bar item shows as its text.
public enum MenuBarMode: String, Sendable, CaseIterable {
    case freeSpace
    case usedSpace
    case percentageFree

    public var menuTitle: String {
        switch self {
        case .freeSpace: return "Free Space"
        case .usedSpace: return "Used Space"
        case .percentageFree: return "Percentage Free"
        }
    }
}

/// Where a scan starts from.
public enum ScanScopeKind: String, Sendable, CaseIterable {
    case wholeDisk
    case home
    case custom

    public var menuTitle: String {
        switch self {
        case .wholeDisk: return "Whole Disk"
        case .home: return "Home Folder"
        case .custom: return "Choose Folder…"
        }
    }
}

/// How results are ordered in the table.
public enum SortMode: String, Sendable, CaseIterable {
    case size
    case name
    case date

    public var menuTitle: String {
        switch self {
        case .size: return "Size"
        case .name: return "Name"
        case .date: return "Date Modified"
        }
    }
}

/// Typed, persisted user preferences backed by `UserDefaults`.
///
/// Each property reads/writes a single key with a sensible default, so the
/// rest of the app never touches `UserDefaults` directly.
@MainActor
public final class Preferences {
    public static let shared = Preferences()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let minimumFileSize = "minimumFileSize"
        static let refreshInterval = "refreshInterval"
        static let alertEnabled = "alertEnabled"
        static let alertThresholdPercent = "alertThresholdPercent"
        static let menuBarMode = "menuBarMode"
        static let selectedVolumePath = "selectedVolumePath"
        static let scanScope = "scanScope"
        static let customScanPath = "customScanPath"
        static let sortMode = "sortMode"
    }

    public var minimumFileSize: Int64 {
        get {
            defaults.object(forKey: Key.minimumFileSize) != nil
                ? Int64(defaults.integer(forKey: Key.minimumFileSize))
                : 50_000_000
        }
        set { defaults.set(Int(newValue), forKey: Key.minimumFileSize) }
    }

    public var refreshInterval: TimeInterval {
        get {
            defaults.object(forKey: Key.refreshInterval) != nil
                ? defaults.double(forKey: Key.refreshInterval)
                : 10
        }
        set { defaults.set(newValue, forKey: Key.refreshInterval) }
    }

    public var alertEnabled: Bool {
        get { defaults.object(forKey: Key.alertEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.alertEnabled) }
    }

    public var alertThresholdPercent: Int {
        get {
            defaults.object(forKey: Key.alertThresholdPercent) != nil
                ? defaults.integer(forKey: Key.alertThresholdPercent)
                : 10
        }
        set { defaults.set(newValue, forKey: Key.alertThresholdPercent) }
    }

    public var menuBarMode: MenuBarMode {
        get { MenuBarMode(rawValue: defaults.string(forKey: Key.menuBarMode) ?? "") ?? .freeSpace }
        set { defaults.set(newValue.rawValue, forKey: Key.menuBarMode) }
    }

    public var selectedVolumePath: String? {
        get { defaults.string(forKey: Key.selectedVolumePath) }
        set { defaults.set(newValue, forKey: Key.selectedVolumePath) }
    }

    public var scanScope: ScanScopeKind {
        get { ScanScopeKind(rawValue: defaults.string(forKey: Key.scanScope) ?? "") ?? .wholeDisk }
        set { defaults.set(newValue.rawValue, forKey: Key.scanScope) }
    }

    public var customScanPath: String? {
        get { defaults.string(forKey: Key.customScanPath) }
        set { defaults.set(newValue, forKey: Key.customScanPath) }
    }

    public var sortMode: SortMode {
        get { SortMode(rawValue: defaults.string(forKey: Key.sortMode) ?? "") ?? .size }
        set { defaults.set(newValue.rawValue, forKey: Key.sortMode) }
    }
}

/// Resolves preferences into concrete URLs for monitoring and scanning, so the
/// menu (AppDelegate) and the popover share one source of truth.
@MainActor
public enum ScanRootResolver {

    /// The volume whose free space the menu-bar gauge reflects.
    public static func monitoredVolumeURL(preferences: Preferences) -> URL {
        URL(fileURLWithPath: preferences.selectedVolumePath ?? "/")
    }

    /// The directory a scan should start from, per the chosen scope.
    public static func resolve(preferences: Preferences) -> URL {
        switch preferences.scanScope {
        case .home:
            return FileManager.default.homeDirectoryForCurrentUser
        case .custom:
            if let path = preferences.customScanPath {
                return URL(fileURLWithPath: path)
            }
            return FileManager.default.homeDirectoryForCurrentUser
        case .wholeDisk:
            return monitoredVolumeURL(preferences: preferences)
        }
    }
}
