// Sources/DiskSpaceKit/AppDelegate.swift
import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var barView: StatusBarView?
    private var updateTimer: Timer?
    private var popover: NSPopover?

    let scanner = DiskScanner()
    let preferences = Preferences.shared
    private let alerter = LowSpaceAlerter()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        scanner.setMinimumFileSize(preferences.minimumFileSize)
        buildMainMenu()
        setupStatusItem()
        setupPopover()
        startTimer()
        refresh()
        alerter.requestAuthorization()
        startScanNow()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
        scanner.cancel()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        let view = StatusBarView(frame: NSRect(x: 0, y: 0, width: 110, height: 22))
        view.autoresizingMask = [.width, .height]
        view.mode = preferences.menuBarMode
        button.addSubview(view)
        button.frame = view.frame
        barView = view

        button.target = self
        button.action = #selector(statusBarClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("DiskSpace — free disk space")

        // No attached menu: we decide popover vs. menu per click below.
        statusItem?.menu = nil
    }

    @objc private func statusBarClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if wantsMenu {
            showStatusMenu()
        } else {
            togglePopover()
        }
    }

    private func showStatusMenu() {
        guard let button = statusItem?.button else { return }
        let menu = buildStatusMenu()
        let origin = NSPoint(x: 0, y: button.bounds.height + 5)
        menu.popUp(positioning: nil, at: origin, in: button)
    }

    // MARK: - Popover

    private func setupPopover() {
        let viewController = PopoverViewController(scanner: scanner)
        let pop = NSPopover()
        pop.contentViewController = viewController
        pop.contentSize = NSSize(width: 420, height: 560)
        pop.behavior = .transient // closes when clicking outside
        pop.animates = true
        popover = pop
    }

    func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: preferences.refreshInterval, repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    func refresh() {
        let url = ScanRootResolver.monitoredVolumeURL(preferences: preferences)
        guard let info = try? DiskInfo.readVolume(at: url) else { return }
        barView?.diskInfo = info
        barView?.mode = preferences.menuBarMode

        let name = (try? DiskInfo.volumeName(at: url)) ?? "Disk"
        alerter.evaluate(
            freePercent: info.freeFraction * 100,
            thresholdPercent: preferences.alertThresholdPercent,
            enabled: preferences.alertEnabled,
            volumeName: name
        )
    }

    // MARK: - Scanning

    /// Start a scan using the current persisted scope/volume/threshold.
    func startScanNow() {
        scanner.setMinimumFileSize(preferences.minimumFileSize)
        scanner.startScan(rootURL: ScanRootResolver.resolve(preferences: preferences))
    }
}
