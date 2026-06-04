import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` for "Launch at Login".
///
/// Requires the app to run from a registered `.app` bundle (it does once
/// installed). Status changes are idempotent and throw on failure so callers
/// can surface an error.
public enum LoginItem {

    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled { try service.register() }
        } else {
            if service.status == .enabled { try service.unregister() }
        }
    }
}
