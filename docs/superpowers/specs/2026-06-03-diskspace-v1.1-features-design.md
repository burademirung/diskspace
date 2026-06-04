# DiskSpace v1.1 — Feature Expansion

**Date:** 2026-06-03
**Status:** Implemented

Adds the features a menu-bar disk utility is expected to have, across four
bundles the user approved. Foundation logic lives in new single-purpose files;
AppKit wiring extends `AppDelegate` and `PopoverViewController`.

## Bundle 1 — Essentials (closes broken basics)

- **Status-item menu + Quit.** Right-click / control-click the menu-bar item
  opens an `NSMenu` (Open, Scan Now, Refresh, Scan Scope, Volume, Show in Menu
  Bar, Low Space Alerts, Launch at Login, About, **Quit ⌘Q**). A minimal
  `NSApp.mainMenu` provides ⌘Q when the popover is key. *Previously there was no
  way to quit the app at all.*
- **Launch at Login** via `SMAppService.mainApp` (`LoginItem`).
- **Full Disk Access detection** (`DiskAccess`): probes TCC-protected files; a
  yellow banner in the popover with "Open Settings" appears when FDA is missing
  (otherwise scans silently under-report).
- **Persisted preferences** (`Preferences` over `UserDefaults`): threshold,
  refresh interval, alert settings, menu-bar mode, volume, scope, sort.

## Bundle 2 — Monitoring

- **Low-space alerts** (`LowSpaceAlerter`, `UserNotifications`): one notification
  per threshold crossing, with hysteresis; configurable Off/5/10/15/20%.
- **Menu-bar display mode**: Free / Used / Percentage Free (`StatusBarView.mode`).
- **Multiple volumes**: `DiskInfo.mountedVolumes()`; pick which volume the gauge
  monitors and scans.

## Bundle 3 — Analysis

- **Scan scope**: Whole Disk / Home Folder / Choose Folder (`ScanRootResolver`,
  `NSOpenPanel`). The scanner skips system dirs (`/dev`, `/Volumes`, VM swap)
  only on a whole-disk scan.
- **Modification-date column + sort** by Size / Name / Date. `FolderItem` now
  tracks the most-recent descendant mtime.
- **Search/filter** box filters results by path.
- **Drill into folders**: double-click a folder → scoped scan of it.

## Bundle 4 — Cleanup

- **Suggested cleanup** tab (`CleanupTargets`): User Caches, Xcode DerivedData /
  iOS DeviceSupport, CoreSimulator Caches, Trash, plus `node_modules` found in
  the scan. Sizes computed off the main actor.
- Non-permanent targets move their **contents** to the Trash (recoverable);
  the Trash target empties permanently, behind an explicit confirmation.

## Verification

- Clean release build, SwiftLint 0 violations, Semgrep 0 findings.
- App launches, survives (notification/menu init OK), and **quits cleanly**.
- **Not verified here**: visual layout of the popover (no Screen Recording
  permission) and the test target (`import Testing` needs full Xcode). The
  three new tuples were refactored to a struct after lint flagged them.

## Out of scope

Notarization / App Store / treemap visualization / breadcrumb back-navigation.
