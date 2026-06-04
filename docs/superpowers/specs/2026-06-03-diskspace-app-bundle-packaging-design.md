# DiskSpace — `.app` Bundle Packaging & Local Install

**Date:** 2026-06-03
**Status:** Approved (user: "just finish it")

## Goal

Make DiskSpace launchable from the user's `/Applications` folder (Finder,
Launchpad, Spotlight) as a normal double-clickable app, instead of a bare
SPM executable run from the terminal.

This is **local install only** — not App Store, notarization, or paid
distribution. Those are explicitly out of scope.

## Background

`swift build` produces a bare Mach-O executable at `.build/release/DiskSpace`.
macOS only treats a `.app` bundle (a specific folder layout) as a launchable
application. The repo is intentionally SPM-only with no Xcode project; the
existing `Info.plist` is injected into the binary via linker `-sectcreate`
flags. The app is a menu-bar agent (`LSUIElement=true`): no Dock icon, no
window — double-clicking adds the disk gauge to the menu bar.

## Approach

Add a packaging layer on top of `swift build` (no Xcode project), so the
"one command from the CLI" workflow is preserved and repeatable.

### Components

1. **`scripts/make-icon.swift`** — pure AppKit program (no external tools).
   Draws a disk-gauge motif (rounded-rect tile, blue→indigo gradient,
   centered capsule gauge with a green fill — echoing the menu-bar bar) and
   renders every required iconset pixel size. Piped through `iconutil` to
   produce `AppIcon.icns`. Generated once and cached in `.build/`.

2. **`scripts/package.sh`** — entry point. Steps:
   - `swift build -c release`
   - generate/refresh icon if missing
   - assemble `DiskSpace.app/Contents/` with `MacOS/DiskSpace`, a file-based
     `Info.plist` (existing keys + `CFBundleIconFile`, `CFBundlePackageType`,
     `NSHighResolutionCapable`, `LSMinimumSystemVersion`), and
     `Resources/AppIcon.icns`
   - ad-hoc code-sign (`codesign --force --deep --sign -`) so Gatekeeper runs
     it cleanly on this machine
   - stop any running instance, then install to `/Applications/DiskSpace.app`
     (in-place `cp -R` if writable; otherwise prompt the user to run the copy)

### Data flow

```
swift build -c release ─► .build/release/DiskSpace (Mach-O)
make-icon.swift ─► AppIcon.iconset ─iconutil─► .build/AppIcon.icns
        └─► DiskSpace.app/Contents/{MacOS/DiskSpace, Info.plist, Resources/AppIcon.icns}
              └─ codesign --sign - ─► /Applications/DiskSpace.app ─► Spotlight/Launchpad/Finder
```

## Behavior after install

Launching from Applications/Spotlight/Launchpad starts the menu-bar agent:
disk gauge in the menu bar, no window, no Dock icon. Quit from the popover.

## Verification

- `swift test` — existing suite still green (no regression)
- run `package.sh`, then `open -a DiskSpace`
- confirm process alive and registered as a background UI agent
- confirm `mdfind`/Spotlight indexes `/Applications/DiskSpace.app`

## Out of scope

Notarization, Developer ID signing, App Store, launch-at-login, payments.
