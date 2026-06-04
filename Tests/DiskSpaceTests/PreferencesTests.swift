import Testing
import Foundation
@testable import DiskSpaceKit

@MainActor
@Suite("Preferences Tests")
struct PreferencesTests {

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "diskspace-test-\(UUID().uuidString)") ?? .standard
    }

    @Test("Unset preferences return sensible defaults")
    func defaults() {
        let prefs = Preferences(defaults: isolatedDefaults())
        #expect(prefs.minimumFileSize == 50_000_000)
        #expect(prefs.refreshInterval == 10)
        #expect(prefs.alertEnabled)
        #expect(prefs.alertThresholdPercent == 10)
        #expect(prefs.menuBarMode == .freeSpace)
        #expect(prefs.scanScope == .wholeDisk)
        #expect(prefs.sortMode == .size)
        #expect(prefs.selectedVolumePath == nil)
    }

    @Test("Values round-trip through the backing store")
    func roundTrip() {
        let defaults = isolatedDefaults()
        let prefs = Preferences(defaults: defaults)
        prefs.minimumFileSize = 100_000_000
        prefs.refreshInterval = 30
        prefs.alertEnabled = false
        prefs.alertThresholdPercent = 15
        prefs.menuBarMode = .percentageFree
        prefs.scanScope = .home
        prefs.sortMode = .date
        prefs.selectedVolumePath = "/Volumes/External"
        prefs.customScanPath = "/Users/me/Projects"

        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.minimumFileSize == 100_000_000)
        #expect(reloaded.refreshInterval == 30)
        #expect(!reloaded.alertEnabled)
        #expect(reloaded.alertThresholdPercent == 15)
        #expect(reloaded.menuBarMode == .percentageFree)
        #expect(reloaded.scanScope == .home)
        #expect(reloaded.sortMode == .date)
        #expect(reloaded.selectedVolumePath == "/Volumes/External")
        #expect(reloaded.customScanPath == "/Users/me/Projects")
    }

    @Test("Unknown stored enum raw values fall back to the default")
    func enumFallback() {
        let defaults = isolatedDefaults()
        defaults.set("nonsense", forKey: "menuBarMode")
        defaults.set("nonsense", forKey: "scanScope")
        defaults.set("nonsense", forKey: "sortMode")
        let prefs = Preferences(defaults: defaults)
        #expect(prefs.menuBarMode == .freeSpace)
        #expect(prefs.scanScope == .wholeDisk)
        #expect(prefs.sortMode == .size)
    }
}

@MainActor
@Suite("ScanRootResolver Tests")
struct ScanRootResolverTests {

    private func prefs() -> Preferences {
        Preferences(defaults: UserDefaults(suiteName: "diskspace-test-\(UUID().uuidString)") ?? .standard)
    }

    @Test("Whole-disk scope uses the boot volume, then the selected volume")
    func wholeDisk() {
        let preferences = prefs()
        preferences.scanScope = .wholeDisk
        #expect(ScanRootResolver.resolve(preferences: preferences).path == "/")
        preferences.selectedVolumePath = "/Volumes/External"
        #expect(ScanRootResolver.resolve(preferences: preferences).path == "/Volumes/External")
    }

    @Test("Home scope resolves to the home directory")
    func home() {
        let preferences = prefs()
        preferences.scanScope = .home
        #expect(ScanRootResolver.resolve(preferences: preferences) == FileManager.default.homeDirectoryForCurrentUser)
    }

    @Test("Custom scope resolves to the stored path")
    func custom() {
        let preferences = prefs()
        preferences.scanScope = .custom
        preferences.customScanPath = "/tmp/diskspace-scope"
        #expect(ScanRootResolver.resolve(preferences: preferences).path == "/tmp/diskspace-scope")
    }
}
