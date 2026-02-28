# DiskSpace — macOS Menu Bar App Design

## Overview

A native macOS menu bar utility that shows free disk space in real time for the boot volume.

## Requirements

- Menu bar app (no Dock icon, no main window)
- Displays a colored percentage bar + free space number in the menu bar
- Dropdown menu shows free, used, and total space
- Monitors boot volume only
- Refreshes every 10 seconds

## Technology

- **Language:** Swift 6.2, Swift Package Manager
- **UI:** NSStatusItem with custom NSView (menu bar), NSMenu (dropdown)
- **Disk API:** FileManager / URL.resourceValues with volumeAvailableCapacityForImportantUsageKey
- **Build:** `swift build` from CLI (no Xcode project required)

## Architecture

```
DiskSpace/
├── Package.swift
└── Sources/
    └── DiskSpace/
        ├── main.swift           # Entry point, NSApplication setup
        ├── AppDelegate.swift    # NSStatusItem, timer, menu management
        ├── DiskMonitor.swift    # Reads disk space via FileManager
        └── StatusBarView.swift  # Custom NSView: percentage bar + text
```

## Menu Bar Display

A custom NSView rendered in the status bar:

```
[████████░░] 142 GB
```

- ~40px wide rounded bar showing used/total ratio
- Color: green (>20% free), yellow (10-20% free), red (<10% free)
- Free space text in system font to the right
- Total width: ~110px

## Dropdown Menu

Standard NSMenu shown on click:

```
Macintosh HD
Free:   142.3 GB
Used:   357.7 GB
Total:  500.0 GB
────────────────
Quit DiskSpace
```

- Volume name as disabled header
- Three info rows (disabled, non-clickable)
- Separator + Quit item

## Data & Behavior

- **Disk reading:** `URL.resourceValues(forKeys:)` with `.volumeAvailableCapacityForImportantUsageKey` and `.volumeTotalCapacityKey`
- **Refresh:** Timer fires every 10 seconds on RunLoop (auto-pauses on sleep)
- **Formatting:** ByteCountFormatter with .file style, 1 decimal place
- **Lifecycle:** LSUIElement = true (no Dock icon), quit via menu

## Out of Scope (v1)

- Multiple volumes
- Launch at login
- Purgeable space display
- Notifications / alerts
