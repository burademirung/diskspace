// Sources/DiskSpaceKit/AppDelegate+Menu.swift
import AppKit

extension AppDelegate {

    // MARK: - Main menu (provides ⌘Q when a window/popover is key)

    func buildMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)

        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "About DiskSpace",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit DiskSpace",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        for item in appMenu.items { item.target = self }
        appItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Status-item right-click menu

    func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()

        addItem(to: menu, "Open DiskSpace", #selector(openPopoverFromMenu))
        addItem(to: menu, "Scan Now", #selector(scanNow))
        addItem(to: menu, "Refresh", #selector(refreshNow))
        menu.addItem(.separator())

        menu.addItem(scopeMenuItem())
        menu.addItem(volumeMenuItem())
        menu.addItem(displayMenuItem())
        menu.addItem(alertsMenuItem())

        let loginItem = addItem(to: menu, "Launch at Login", #selector(toggleLaunchAtLogin))
        loginItem.state = LoginItem.isEnabled ? .on : .off

        menu.addItem(.separator())
        addItem(to: menu, "About DiskSpace", #selector(showAbout))
        let quitItem = addItem(to: menu, "Quit DiskSpace", #selector(quit))
        quitItem.keyEquivalent = "q"

        return menu
    }

    @discardableResult
    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    private func scopeMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Scan Scope", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for scope in ScanScopeKind.allCases {
            let item = NSMenuItem(
                title: scope.menuTitle, action: #selector(selectScanScope(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = scope.rawValue
            item.state = (scope == preferences.scanScope) ? .on : .off
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    private func volumeMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let selected = preferences.selectedVolumePath ?? "/"
        for volume in DiskInfo.mountedVolumes() {
            let item = NSMenuItem(
                title: volume.name, action: #selector(selectVolume(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = volume.url.path
            item.state = (volume.url.path == selected) ? .on : .off
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    private func displayMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Show in Menu Bar", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for mode in MenuBarMode.allCases {
            let item = NSMenuItem(
                title: mode.menuTitle, action: #selector(selectDisplayMode(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            item.state = (mode == preferences.menuBarMode) ? .on : .off
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    private func alertsMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Low Space Alerts", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let off = NSMenuItem(title: "Off", action: #selector(selectAlertThreshold(_:)), keyEquivalent: "")
        off.target = self
        off.representedObject = 0
        off.state = preferences.alertEnabled ? .off : .on
        submenu.addItem(off)
        submenu.addItem(.separator())

        for percent in [5, 10, 15, 20] {
            let item = NSMenuItem(
                title: "Below \(percent)% free",
                action: #selector(selectAlertThreshold(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = percent
            let active = preferences.alertEnabled && preferences.alertThresholdPercent == percent
            item.state = active ? .on : .off
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    // MARK: - Actions

    @objc func openPopoverFromMenu() {
        togglePopover()
    }

    @objc func scanNow() {
        startScanNow()
    }

    @objc func refreshNow() {
        refresh()
    }

    @objc func selectScanScope(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let scope = ScanScopeKind(rawValue: raw) else { return }
        if scope == .custom {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Scan"
            panel.message = "Choose a folder to scan"
            NSApp.activate(ignoringOtherApps: true)
            guard panel.runModal() == .OK, let url = panel.url else { return }
            preferences.customScanPath = url.path
        }
        preferences.scanScope = scope
        startScanNow()
    }

    @objc func selectVolume(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        preferences.selectedVolumePath = path
        refresh()
    }

    @objc func selectDisplayMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = MenuBarMode(rawValue: raw) else { return }
        preferences.menuBarMode = mode
        refresh()
    }

    @objc func selectAlertThreshold(_ sender: NSMenuItem) {
        guard let percent = sender.representedObject as? Int else { return }
        if percent == 0 {
            preferences.alertEnabled = false
        } else {
            preferences.alertEnabled = true
            preferences.alertThresholdPercent = percent
        }
        refresh()
    }

    @objc func toggleLaunchAtLogin() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            NSLog("Launch at Login change failed: \(error)")
        }
    }

    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "DiskSpace",
            .applicationVersion: "1.1"
        ])
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
