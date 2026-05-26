import AppKit

extension PopoverViewController {

    func setupSummary() {
        summaryBar.style = .bar
        summaryBar.isIndeterminate = false
        summaryBar.minValue = 0
        summaryBar.maxValue = 100
        summaryBar.doubleValue = 0

        summaryLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        summaryLabel.alignment = .left
    }

    func setupToolbar() {
        tabControl.segmentStyle = .rounded

        for option in thresholdOptions {
            thresholdPicker.addItem(withTitle: option.label)
        }

        scanButton.bezelStyle = .rounded
        scanButton.setButtonType(.momentaryPushIn)

        cancelButton.bezelStyle = .rounded
        cancelButton.setButtonType(.momentaryPushIn)
        cancelButton.isHidden = true
    }

    func setupTable() {
        let checkCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("check"))
        checkCol.title = ""
        checkCol.width = 28
        checkCol.minWidth = 28
        checkCol.maxWidth = 28
        tableView.addTableColumn(checkCol)

        // Size column (shown before path so sizes are visible on the left)
        let sizeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeCol.title = "Size"
        sizeCol.width = 80
        sizeCol.minWidth = 60
        tableView.addTableColumn(sizeCol)

        let pathCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        pathCol.title = "Path"
        pathCol.width = 280
        pathCol.minWidth = 150
        tableView.addTableColumn(pathCol)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 22
        tableView.headerView = NSTableHeaderView()

        let contextMenu = NSMenu()
        contextMenu.addItem(
            NSMenuItem(
                title: "Reveal in Finder",
                action: #selector(revealInFinder(_:)),
                keyEquivalent: ""
            )
        )
        tableView.menu = contextMenu

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
    }

    func setupStatusBar() {
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        deleteButton.bezelStyle = .rounded
        deleteButton.setButtonType(.momentaryPushIn)
        deleteButton.isEnabled = false
    }

    func layoutSubviews() {
        let views: [NSView] = [
            summaryBar, summaryLabel, tabControl, thresholdLabel,
            thresholdPicker, scrollView, statusLabel, scanButton,
            cancelButton, deleteButton
        ]
        for subview in views {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        let pad: CGFloat = 12
        let smallPad: CGFloat = 8

        NSLayoutConstraint.activate([
            summaryBar.topAnchor.constraint(equalTo: view.topAnchor, constant: pad),
            summaryBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            summaryBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            summaryLabel.topAnchor.constraint(equalTo: summaryBar.bottomAnchor, constant: 4),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            tabControl.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: smallPad),
            tabControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            scanButton.centerYAnchor.constraint(equalTo: tabControl.centerYAnchor),
            scanButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            cancelButton.centerYAnchor.constraint(equalTo: tabControl.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: scanButton.leadingAnchor, constant: -smallPad),

            thresholdLabel.topAnchor.constraint(equalTo: tabControl.bottomAnchor, constant: smallPad),
            thresholdLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            thresholdPicker.centerYAnchor.constraint(equalTo: thresholdLabel.centerYAnchor),
            thresholdPicker.leadingAnchor.constraint(equalTo: thresholdLabel.trailingAnchor, constant: 4),

            scrollView.topAnchor.constraint(equalTo: thresholdLabel.bottomAnchor, constant: smallPad),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),

            statusLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: smallPad),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            statusLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -smallPad),

            deleteButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            deleteButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -pad),

            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -smallPad)
        ])
    }

    func wireActions() {
        tabControl.target = self
        tabControl.action = #selector(tabChanged(_:))

        thresholdPicker.target = self
        thresholdPicker.action = #selector(thresholdChanged(_:))

        scanButton.target = self
        scanButton.action = #selector(scanTapped(_:))

        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped(_:))

        deleteButton.target = self
        deleteButton.action = #selector(deleteTapped(_:))
    }
}
