# Changelog

All notable changes to DiskSpace. Dates are ISO‑8601.

## 1.2 — 2026-06-03

### Changed
- **Parallel disk scan** — top-level subdirectories are now walked concurrently
  with a bounded `TaskGroup` (core count, capped at 64), reusing the proven
  per-subtree walk and merging folder totals by summing shared ancestors.
  Measured **~4.2× faster** on a 10-core machine; validated byte-identical to
  the previous sequential walk. See [docs/RESEARCH-scan-speedup.md](docs/RESEARCH-scan-speedup.md).
- Bumped `swift-tools-version` to 6.3.

### Tooling
- `scripts/benchmark-scan.swift` — measure sequential vs parallel walk on real
  hardware (the research's "measure first" guidance).
- Code cleanup pass; SwiftLint and Semgrep both clean (zero findings).

## 1.1 — 2026-06-03

### Added
- Status-bar right-click menu with **Quit (⌘Q)**, Scan Now, Refresh, About — the
  app previously had no way to quit.
- **Launch at Login** (`SMAppService`).
- **Full Disk Access** detection with an in-popover banner + one-click Settings.
- Persisted preferences (`UserDefaults`).
- **Low-space notifications**, menu-bar display modes (free / used / %), and
  **multiple-volume** monitoring.
- **Scan scope** (whole disk / Home / chosen folder), modification-date column,
  sort by size/name/date, search/filter, double-click drill-down, and a
  click-to-sort / Space-to-toggle results table with empty-state messaging.
- **Cleanup** tab: caches, Xcode DerivedData / iOS DeviceSupport, CoreSimulator
  caches, `node_modules`, and Trash — reclaimable items go to the Trash;
  emptying the Trash is permanent and confirmed.

### Distribution
- Packaged as a notarized **universal** (Apple Silicon + Intel) `.app` in a DMG;
  `scripts/release.sh` does Developer ID signing → notarization → stapling → DMG.
- Homebrew cask: `brew install --cask burademirung/tap/diskspace`.
- MIT licensed.
