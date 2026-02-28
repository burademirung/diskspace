// Sources/DiskSpaceKit/AppDelegate.swift
import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var barView: StatusBarView?
    private var updateTimer: Timer?

    // Menu items that need updating
    private var freeItem: NSMenuItem?
    private var usedItem: NSMenuItem?
    private var totalItem: NSMenuItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()
        startTimer()
        refresh()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        let view = StatusBarView(frame: NSRect(x: 0, y: 0, width: 110, height: 22))
        view.autoresizingMask = [.width, .height]
        button.addSubview(view)
        button.frame = view.frame
        barView = view
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Volume name header
        do {
            let name = (try? DiskInfo.volumeName()) ?? "Macintosh HD"
            let header = NSMenuItem(title: name, action: nil, keyEquivalent: "")
            header.isEnabled = false
            let font = NSFont.boldSystemFont(ofSize: 13)
            header.attributedTitle = NSAttributedString(string: name, attributes: [.font: font])
            menu.addItem(header)
        }

        menu.addItem(NSMenuItem.separator())

        // Info rows
        freeItem = NSMenuItem(title: "Free:  --", action: nil, keyEquivalent: "")
        freeItem?.isEnabled = false
        menu.addItem(freeItem!)

        usedItem = NSMenuItem(title: "Used:  --", action: nil, keyEquivalent: "")
        usedItem?.isEnabled = false
        menu.addItem(usedItem!)

        totalItem = NSMenuItem(title: "Total: --", action: nil, keyEquivalent: "")
        totalItem?.isEnabled = false
        menu.addItem(totalItem!)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit DiskSpace", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

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

        // Use monospaced digits for alignment
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        freeItem?.attributedTitle = NSAttributedString(
            string: "Free:  \(info.formattedFree)",
            attributes: [.font: font]
        )
        usedItem?.attributedTitle = NSAttributedString(
            string: "Used:  \(info.formattedUsed)",
            attributes: [.font: font]
        )
        totalItem?.attributedTitle = NSAttributedString(
            string: "Total: \(info.formattedTotal)",
            attributes: [.font: font]
        )
    }
}
