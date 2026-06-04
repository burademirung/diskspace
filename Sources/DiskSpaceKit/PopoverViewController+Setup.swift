import AppKit

extension PopoverViewController {

    func setupFDABanner() {
        fdaBanner.wantsLayer = true
        fdaBanner.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.18).cgColor

        fdaLabel.font = .systemFont(ofSize: 11)
        fdaLabel.textColor = .secondaryLabelColor
        fdaLabel.lineBreakMode = .byTruncatingTail
        fdaLabel.maximumNumberOfLines = 2

        fdaButton.bezelStyle = .rounded
        fdaButton.controlSize = .small
        fdaButton.setButtonType(.momentaryPushIn)
    }

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

        sortLabel.font = .systemFont(ofSize: 11)
        sortLabel.textColor = .secondaryLabelColor
        for mode in SortMode.allCases {
            sortPicker.addItem(withTitle: mode.menuTitle)
        }

        searchField.placeholderString = "Filter by path"
        searchField.sendsWholeSearchString = false

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

        let sizeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeCol.title = "Size"
        sizeCol.width = 78
        sizeCol.minWidth = 60
        tableView.addTableColumn(sizeCol)

        let dateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateCol.title = "Modified"
        dateCol.width = 78
        dateCol.minWidth = 60
        tableView.addTableColumn(dateCol)

        let pathCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        pathCol.title = "Path"
        pathCol.width = 210
        pathCol.minWidth = 120
        tableView.addTableColumn(pathCol)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 22
        tableView.headerView = NSTableHeaderView()
        tableView.target = self
        tableView.doubleAction = #selector(rowDoubleClicked(_:))

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
        let containers: [NSView] = [fdaLabel, fdaButton]
        for subview in containers {
            subview.translatesAutoresizingMaskIntoConstraints = false
            fdaBanner.addSubview(subview)
        }

        let views: [NSView] = [
            fdaBanner, summaryBar, summaryLabel, tabControl, thresholdLabel,
            thresholdPicker, sortLabel, sortPicker, searchField, scrollView,
            statusLabel, scanButton, cancelButton, deleteButton
        ]
        for subview in views {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        let pad: CGFloat = 12
        let smallPad: CGFloat = 8

        let bannerHeight = fdaBanner.heightAnchor.constraint(equalToConstant: 40)
        fdaBannerHeight = bannerHeight

        NSLayoutConstraint.activate([
            fdaBanner.topAnchor.constraint(equalTo: view.topAnchor),
            fdaBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fdaBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerHeight,

            fdaLabel.leadingAnchor.constraint(equalTo: fdaBanner.leadingAnchor, constant: pad),
            fdaLabel.centerYAnchor.constraint(equalTo: fdaBanner.centerYAnchor),
            fdaButton.trailingAnchor.constraint(equalTo: fdaBanner.trailingAnchor, constant: -pad),
            fdaButton.centerYAnchor.constraint(equalTo: fdaBanner.centerYAnchor),
            fdaLabel.trailingAnchor.constraint(lessThanOrEqualTo: fdaButton.leadingAnchor, constant: -smallPad),

            summaryBar.topAnchor.constraint(equalTo: fdaBanner.bottomAnchor, constant: pad),
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

            sortLabel.centerYAnchor.constraint(equalTo: thresholdLabel.centerYAnchor),
            sortLabel.leadingAnchor.constraint(equalTo: thresholdPicker.trailingAnchor, constant: smallPad),

            sortPicker.centerYAnchor.constraint(equalTo: thresholdLabel.centerYAnchor),
            sortPicker.leadingAnchor.constraint(equalTo: sortLabel.trailingAnchor, constant: 4),
            sortPicker.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -pad),

            searchField.topAnchor.constraint(equalTo: thresholdLabel.bottomAnchor, constant: smallPad),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: smallPad),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            statusLabel.centerYAnchor.constraint(equalTo: deleteButton.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -smallPad),

            deleteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            deleteButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -pad),

            scrollView.bottomAnchor.constraint(equalTo: deleteButton.topAnchor, constant: -smallPad)
        ])
    }

    func wireActions() {
        tabControl.target = self
        tabControl.action = #selector(tabChanged(_:))

        thresholdPicker.target = self
        thresholdPicker.action = #selector(thresholdChanged(_:))

        sortPicker.target = self
        sortPicker.action = #selector(sortChanged(_:))

        searchField.delegate = self

        scanButton.target = self
        scanButton.action = #selector(scanTapped(_:))

        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped(_:))

        deleteButton.target = self
        deleteButton.action = #selector(deleteTapped(_:))

        fdaButton.target = self
        fdaButton.action = #selector(openFDASettings(_:))
    }
}
