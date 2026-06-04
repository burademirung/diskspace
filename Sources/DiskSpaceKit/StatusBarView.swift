// Sources/DiskSpaceKit/StatusBarView.swift
import AppKit

public final class StatusBarView: NSView {

    public var diskInfo = DiskInfo(totalBytes: 1, availableBytes: 1) {
        didSet { needsDisplay = true }
    }

    public var mode: MenuBarMode = .freeSpace {
        didSet { needsDisplay = true }
    }

    private var displayText: String {
        switch mode {
        case .freeSpace: return diskInfo.formattedFree
        case .usedSpace: return diskInfo.formattedUsed
        case .percentageFree: return "\(Int((diskInfo.freeFraction * 100).rounded()))%"
        }
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
        let text = displayText
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
