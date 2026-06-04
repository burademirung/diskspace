import AppKit

/// Detects whether the app has been granted Full Disk Access, and helps the
/// user grant it. Without FDA, scanning `/` silently skips most of the system,
/// so the UI uses this to warn the user instead of under-reporting usage.
public enum DiskAccess {

    /// Heuristic FDA check: try to actually open a TCC-protected file. These
    /// paths are readable only when Full Disk Access is granted.
    public static func hasFullDiskAccess() -> Bool {
        let home = NSHomeDirectory()
        let probes = [
            "\(home)/Library/Application Support/com.apple.TCC/TCC.db",
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "\(home)/Library/Safari/Bookmarks.plist"
        ]
        let fileManager = FileManager.default
        for path in probes where fileManager.fileExists(atPath: path) {
            if let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) {
                try? handle.close()
                return true
            }
        }
        return false
    }

    /// Open System Settings → Privacy & Security → Full Disk Access.
    public static func openSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
