// Sources/DiskSpaceKit/AppDelegate.swift
import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var barView: StatusBarView?
    private var updateTimer: Timer?
    private var popover: NSPopover?
    private let scanner = DiskScanner()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        startTimer()
        refresh()
        scanner.startScan()
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
        button.addSubview(view)
        button.frame = view.frame
        barView = view

        button.target = self
        button.action = #selector(statusBarClicked(_:))
        button.setAccessibilityLabel("DiskSpace — free disk space")

        // Ensure button sends action on click rather than showing a menu
        statusItem?.menu = nil
    }

    @objc private func statusBarClicked(_ sender: Any?) {
        togglePopover()
    }

    // MARK: - Popover

    private func setupPopover() {
        let viewController = PopoverViewController(scanner: scanner)
        let pop = NSPopover()
        pop.contentViewController = viewController
        pop.contentSize = NSSize(width: 420, height: 520)
        pop.behavior = .transient // closes when clicking outside
        pop.animates = true
        popover = pop
    }

    private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    private func refresh() {
        guard let info = try? DiskInfo.readBootVolume() else { return }
        barView?.diskInfo = info
    }
}
