# DiskSpace Menu Bar App — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS menu bar app that shows free disk space as a colored percentage bar + number, with a dropdown showing free/used/total.

**Architecture:** Swift Package Manager executable using NSStatusItem with a custom NSView for the menu bar display. DiskInfo struct handles disk reading via URL.resourceValues. AppDelegate wires the status item, dropdown menu, and a 10-second refresh timer. Info.plist embedded via linker flag hides from Dock.

**Tech Stack:** Swift 6.2, AppKit, Swift Package Manager, Core Graphics

---

### Task 1: Project Scaffolding — Package.swift and Info.plist

**Files:**
- Create: `Package.swift`
- Create: `Sources/DiskSpace/Info.plist`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DiskSpace",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DiskSpace",
            path: "Sources/DiskSpace",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/DiskSpace/Info.plist"
                ])
            ]
        )
    ]
)
```

**Step 2: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleName</key>
    <string>DiskSpace</string>
    <key>CFBundleIdentifier</key>
    <string>com.diskspace.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
```

**Step 3: Create a minimal main.swift to verify the build works**

```swift
// Sources/DiskSpace/main.swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
print("DiskSpace: build OK")
```

**Step 4: Build to verify scaffolding**

Run: `swift build 2>&1`
Expected: Build succeeds with no errors.

**Step 5: Verify Info.plist is embedded**

Run: `otool -l .build/debug/DiskSpace | grep -A3 __info_plist`
Expected: Output shows `__info_plist` section exists.

**Step 6: Commit**

```bash
git add Package.swift Sources/DiskSpace/Info.plist Sources/DiskSpace/main.swift
git commit -m "feat: project scaffolding with Package.swift and Info.plist"
```

---

### Task 2: DiskInfo — Data Model and Disk Reading

**Files:**
- Create: `Sources/DiskSpace/DiskInfo.swift`
- Create: `Tests/DiskSpaceTests/DiskInfoTests.swift`

**Step 1: Create test file with tests for DiskInfo**

```swift
// Tests/DiskSpaceTests/DiskInfoTests.swift
import Testing
@testable import DiskSpace

@Suite("DiskInfo Tests")
struct DiskInfoTests {

    @Test("freeBytes is total minus used")
    func freeBytes() {
        let info = DiskInfo(totalBytes: 500_000_000_000, availableBytes: 142_000_000_000)
        #expect(info.freeBytes == 142_000_000_000)
        #expect(info.usedBytes == 358_000_000_000)
    }

    @Test("usedFraction computes correctly")
    func usedFraction() {
        let info = DiskInfo(totalBytes: 1000, availableBytes: 200)
        #expect(info.usedFraction >= 0.799 && info.usedFraction <= 0.801)
    }

    @Test("usedFraction is 0 when totalBytes is 0")
    func usedFractionZeroTotal() {
        let info = DiskInfo(totalBytes: 0, availableBytes: 0)
        #expect(info.usedFraction == 0)
    }

    @Test("freeFraction computes correctly")
    func freeFraction() {
        let info = DiskInfo(totalBytes: 1000, availableBytes: 200)
        #expect(info.freeFraction >= 0.199 && info.freeFraction <= 0.201)
    }

    @Test("formatted free space shows human-readable GB")
    func formattedFreeSpace() {
        let info = DiskInfo(totalBytes: 500_000_000_000, availableBytes: 142_300_000_000)
        let formatted = info.formattedFree
        // ByteCountFormatter with .file style outputs something like "142.3 GB"
        #expect(formatted.contains("GB"))
    }

    @Test("formatted values for total and used")
    func formattedValues() {
        let info = DiskInfo(totalBytes: 500_000_000_000, availableBytes: 142_300_000_000)
        #expect(info.formattedTotal.contains("GB"))
        #expect(info.formattedUsed.contains("GB"))
    }

    @Test("color is green when more than 20% free")
    func colorGreen() {
        let info = DiskInfo(totalBytes: 1000, availableBytes: 300)
        #expect(info.barColor == .green)
    }

    @Test("color is yellow when 10-20% free")
    func colorYellow() {
        let info = DiskInfo(totalBytes: 1000, availableBytes: 150)
        #expect(info.barColor == .yellow)
    }

    @Test("color is red when less than 10% free")
    func colorRed() {
        let info = DiskInfo(totalBytes: 1000, availableBytes: 50)
        #expect(info.barColor == .red)
    }

    @Test("readBootVolume returns non-zero values")
    func readBootVolume() throws {
        let info = try DiskInfo.readBootVolume()
        #expect(info.totalBytes > 0)
        #expect(info.availableBytes > 0)
        #expect(info.availableBytes <= info.totalBytes)
    }

    @Test("volumeName returns a non-empty string")
    func volumeName() throws {
        let name = try DiskInfo.volumeName()
        #expect(!name.isEmpty)
    }
}
```

Update Package.swift to add test target:

```swift
// In Package.swift targets array, add:
.testTarget(
    name: "DiskSpaceTests",
    dependencies: ["DiskSpace"],
    path: "Tests/DiskSpaceTests"
)
```

But note: since the executable target has `main.swift`, the test target can't link against it directly (you'll get duplicate main symbol). To solve this, we need to extract the library code into a library target and have both the executable and test depend on it.

Revised Package.swift:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DiskSpace",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "DiskSpaceKit",
            path: "Sources/DiskSpaceKit"
        ),
        .executableTarget(
            name: "DiskSpace",
            dependencies: ["DiskSpaceKit"],
            path: "Sources/DiskSpace",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/DiskSpace/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "DiskSpaceTests",
            dependencies: ["DiskSpaceKit"],
            path: "Tests/DiskSpaceTests"
        )
    ]
)
```

**Step 2: Create DiskInfo.swift in DiskSpaceKit**

```swift
// Sources/DiskSpaceKit/DiskInfo.swift
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

    private static let formatter: ByteCountFormatter = {
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
```

**Step 3: Run tests to verify they pass**

Run: `swift test 2>&1`
Expected: All 10 tests pass.

**Step 4: Commit**

```bash
git add Package.swift Sources/DiskSpaceKit/ Tests/DiskSpaceTests/
git commit -m "feat: add DiskInfo data model with disk reading and tests"
```

---

### Task 3: StatusBarView — Custom Menu Bar Drawing

**Files:**
- Create: `Sources/DiskSpaceKit/StatusBarView.swift`

**Step 1: Create StatusBarView.swift**

```swift
// Sources/DiskSpaceKit/StatusBarView.swift
import AppKit

public final class StatusBarView: NSView {

    public var diskInfo: DiskInfo = DiskInfo(totalBytes: 1, availableBytes: 1) {
        didSet { needsDisplay = true }
    }

    private let barWidth: CGFloat = 40
    private let barHeight: CGFloat = 10
    private let padding: CGFloat = 4
    private let textBarGap: CGFloat = 4

    public override var intrinsicContentSize: NSSize {
        let textWidth = textSize().width
        return NSSize(
            width: padding + barWidth + textBarGap + textWidth + padding,
            height: NSStatusBar.system.thickness
        )
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds
        let barY = (bounds.height - barHeight) / 2

        // Background of bar (dark gray rounded rect)
        let barRect = NSRect(x: padding, y: barY, width: barWidth, height: barHeight)
        NSColor.systemGray.withAlphaComponent(0.3).setFill()
        let bgPath = NSBezierPath(roundedRect: barRect, xRadius: 3, yRadius: 3)
        bgPath.fill()

        // Filled portion (used space)
        let filledWidth = barWidth * CGFloat(diskInfo.usedFraction)
        if filledWidth > 0 {
            let filledRect = NSRect(x: padding, y: barY, width: filledWidth, height: barHeight)

            let fillColor: NSColor
            switch diskInfo.barColor {
            case .green: fillColor = .systemGreen
            case .yellow: fillColor = .systemYellow
            case .red: fillColor = .systemRed
            }

            fillColor.setFill()
            let filledPath = NSBezierPath(roundedRect: filledRect, xRadius: 3, yRadius: 3)
            filledPath.fill()
        }

        // Free space text
        let text = diskInfo.formattedFree
        let attrs = textAttributes()
        let textOrigin = NSPoint(
            x: padding + barWidth + textBarGap,
            y: (bounds.height - textSize().height) / 2
        )
        (text as NSString).draw(at: textOrigin, withAttributes: attrs)
    }

    private func textAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
    }

    private func textSize() -> NSSize {
        // Use a representative string for sizing so it doesn't jump around
        let sample = "999.9 GB" as NSString
        return sample.size(withAttributes: textAttributes())
    }

    public override var isOpaque: Bool { false }
}
```

**Step 2: Build to verify it compiles**

Run: `swift build 2>&1`
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add Sources/DiskSpaceKit/StatusBarView.swift
git commit -m "feat: add StatusBarView with colored percentage bar and text"
```

---

### Task 4: AppDelegate — Menu, Timer, and Wiring

**Files:**
- Create: `Sources/DiskSpaceKit/AppDelegate.swift`
- Modify: `Sources/DiskSpace/main.swift`

**Step 1: Create AppDelegate.swift**

```swift
// Sources/DiskSpaceKit/AppDelegate.swift
import AppKit

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
            self?.refresh()
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
```

**Step 2: Update main.swift to use the AppDelegate**

```swift
// Sources/DiskSpace/main.swift
import AppKit
import DiskSpaceKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

**Step 3: Build to verify everything compiles**

Run: `swift build 2>&1`
Expected: Build succeeds.

**Step 4: Run tests to verify nothing is broken**

Run: `swift test 2>&1`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Sources/DiskSpaceKit/AppDelegate.swift Sources/DiskSpace/main.swift
git commit -m "feat: add AppDelegate with menu, timer, and status bar wiring"
```

---

### Task 5: Build, Run, and Verify

**Step 1: Build release binary**

Run: `swift build -c release 2>&1`
Expected: Build succeeds.

**Step 2: Verify Info.plist is embedded**

Run: `otool -l .build/release/DiskSpace | grep -A3 __info_plist`
Expected: Shows the `__info_plist` section.

**Step 3: Run the app and visually verify**

Run: `.build/release/DiskSpace &`

Verify:
- Menu bar shows a colored bar + free space number (e.g. "142.3 GB")
- No Dock icon appears
- Clicking the menu bar item shows dropdown with volume name, free/used/total
- "Quit DiskSpace" menu item works
- Values update every 10 seconds

**Step 4: Kill the test run**

Run: `kill %1` (or use the Quit menu item)

**Step 5: Final commit if any adjustments were needed**

```bash
git add -A
git commit -m "feat: finalize DiskSpace menu bar app v1.0"
```

---

### Task 6: Troubleshooting Reference

If Swift 6.2 strict concurrency causes issues:

1. **Timer closure Sendable error** — ensure `[weak self]` capture
2. **NSView init actor isolation** — add explicit `@MainActor` to init if needed
3. **Module not testable** — ensure DiskSpaceKit is a `.target` (library), not `.executableTarget`
4. **Dock icon still appears** — verify `otool` shows `__info_plist`, check plist path in linkerSettings is relative to package root

If the status bar view doesn't appear:

1. Check `statusItem` is stored as a property (not a local variable)
2. Check `button.addSubview(view)` is called (not deprecated `statusItem.view = ...`)
3. Check `intrinsicContentSize` returns a reasonable width
