# DiskSpace

A free, native macOS menu-bar utility that shows free disk space at a glance and
helps you find and reclaim large files and folders.

![menu bar gauge](docs/screenshot.png)

## Features

- **Menu-bar gauge** — a colored bar + readout (free / used / percentage) for the
  volume you choose. Green / yellow / red as space runs low.
- **Disk analyzer** — scan the whole disk, your Home folder, or any chosen
  folder; see the largest files and folders, sorted by size, name, or date.
- **Search & drill-down** — filter results by path; double-click a folder to
  scan into it.
- **Cleanup** — one-click reclaim of common space hogs (caches, Xcode
  DerivedData, iOS DeviceSupport, CoreSimulator caches, `node_modules`, Trash).
  Reclaimable items move to the Trash (recoverable); emptying the Trash is
  permanent and always confirmed.
- **Low-space alerts** — a notification when free space drops below a threshold
  you set (5–20%).
- **Multiple volumes**, **Launch at Login**, and a **Full Disk Access** prompt so
  scans see your whole disk.

## Install

### Download (recommended)

**[⬇︎ Download the latest DiskSpace.dmg](../../releases/latest)**

Open the DMG and drag **DiskSpace** to **Applications**. The build is signed and
notarized by Apple, so it runs without Gatekeeper warnings — just open it.

### Build from source

Requires macOS 14+ and a Swift 6 toolchain (Xcode or Command Line Tools).

```sh
git clone <this-repo>
cd diskspace
scripts/package.sh        # builds, bundles, ad-hoc signs, installs to /Applications
```

## Full Disk Access

To scan your whole disk, grant Full Disk Access:
**System Settings → Privacy & Security → Full Disk Access → enable DiskSpace.**
The app shows a banner with a one-click shortcut to this screen when access is
missing. Without it, scans silently skip protected areas.

## Usage

- **Left-click** the menu-bar item → opens the analyzer popover.
- **Right-click** (or Control-click) → menu: Scan, Scope, Volume, display mode,
  alerts, Launch at Login, About, and **Quit**.
- In the popover: pick a tab (Folders / Files / Cleanup), set a minimum size,
  sort by clicking a column header, filter with the search box, check items, and
  **Move to Trash** / **Clean Up**.

## Privacy

DiskSpace runs entirely on your Mac. It makes **no network connections**, has
**zero third-party dependencies**, and collects nothing.

## License

[MIT](LICENSE).
