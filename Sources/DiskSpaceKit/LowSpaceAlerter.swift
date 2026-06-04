import Foundation
import UserNotifications

/// Posts a local notification when free space on the monitored volume drops
/// below a threshold. Uses hysteresis + a latch so the user gets one alert per
/// crossing, not one every refresh tick.
@MainActor
public final class LowSpaceAlerter {

    private var hasAlerted = false

    public init() {}

    /// Ask the user for notification permission once. Safe to call repeatedly.
    public func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Evaluate the current free-space percentage against the threshold.
    /// Call on every refresh; it self-throttles.
    public func evaluate(
        freePercent: Double,
        thresholdPercent: Int,
        enabled: Bool,
        volumeName: String
    ) {
        guard enabled else {
            hasAlerted = false
            return
        }

        let threshold = Double(thresholdPercent)
        if freePercent < threshold {
            guard !hasAlerted else { return }
            hasAlerted = true
            post(freePercent: freePercent, volumeName: volumeName)
        } else if freePercent > threshold + 2 {
            // Recovered comfortably above the threshold — re-arm the alert.
            hasAlerted = false
        }
    }

    private func post(freePercent: Double, volumeName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Low Disk Space"
        content.body = String(
            format: "%@ is only %.0f%% free.", volumeName, freePercent
        )
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "diskspace.lowspace.\(volumeName)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
