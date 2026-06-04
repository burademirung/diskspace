// Offscreen layout harness — renders the popover view to PNGs so the layout
// can be inspected without a running app or Screen Recording permission.
// Compiled together with DiskSpaceKit sources as one module (see usage below).
import AppKit

@MainActor
func renderPopover(fdaVisible: Bool, tab: Int, loadCleanup: Bool, outPath: String) {
    let scanner = DiskScanner()
    let viewController = PopoverViewController(scanner: scanner)

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentViewController = viewController
    _ = viewController.view

    viewController.tabControl.selectedSegment = tab

    // Force the Full Disk Access banner visible for inspection.
    viewController.fdaBanner.isHidden = !fdaVisible
    viewController.fdaBannerHeight?.constant = fdaVisible ? 40 : 0

    if loadCleanup {
        viewController.loadCleanup()
    }

    guard let content = window.contentView else { return }
    content.frame = NSRect(x: 0, y: 0, width: 420, height: 560)
    content.layoutSubtreeIfNeeded()

    guard let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { return }
    content.cacheDisplay(in: content.bounds, to: rep)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath)")
}

@main
enum RenderMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        MainActor.assumeIsolated {
            renderPopover(fdaVisible: true, tab: 0, loadCleanup: false,
                          outPath: "/tmp/popover_folders.png")
            renderPopover(fdaVisible: false, tab: 2, loadCleanup: true,
                          outPath: "/tmp/popover_cleanup.png")
        }
    }
}
