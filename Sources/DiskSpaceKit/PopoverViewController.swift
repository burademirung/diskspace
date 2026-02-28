import AppKit

@MainActor
public final class PopoverViewController: NSViewController,
    NSTableViewDataSource, NSTableViewDelegate {

    private let scanner: DiskScanner

    // UI elements
    private let summaryLabel = NSTextField(labelWithString: "")
    private let summaryBar = NSProgressIndicator()
    private let tabControl = NSSegmentedControl(
        labels: ["Folders", "Files"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let thresholdLabel = NSTextField(labelWithString: "Min size:")
    private let thresholdPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let statusLabel = NSTextField(labelWithString: "Ready")
    private let scanButton = NSButton(
        title: "Scan",
        target: nil,
        action: nil
    )
    private let cancelButton = NSButton(
        title: "Cancel",
        target: nil,
        action: nil
    )
    private let deleteButton = NSButton(
        title: "Move to Trash",
        target: nil,
        action: nil
    )

    // State
    private var showingFiles = false
    private var checkedURLs: Set<URL> = []
    private var displayedFiles: [FileItem] = []
    private var displayedFolders: [FolderItem] = []

    // Threshold options in bytes
    private let thresholdOptions: [(label: String, bytes: Int64)] = [
        ("10 MB", 10_000_000),
        ("50 MB", 50_000_000),
        ("100 MB", 100_000_000),
        ("500 MB", 500_000_000),
        ("1 GB", 1_000_000_000),
    ]

    public init(scanner: DiskScanner) {
        self.scanner = scanner
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 520))
        self.view = container
        setupSummary()
        setupToolbar()
        setupTable()
        setupStatusBar()
        layoutSubviews()
        wireActions()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        scanner.onUpdate = { [weak self] in
            self?.handleScannerUpdate()
        }
        tabControl.selectedSegment = 0
        thresholdPicker.selectItem(at: 1) // 50 MB default
        handleScannerUpdate()
    }

    // MARK: - Setup

    private func setupSummary() {
        summaryBar.style = .bar
        summaryBar.isIndeterminate = false
        summaryBar.minValue = 0
        summaryBar.maxValue = 100
        summaryBar.doubleValue = 0

        summaryLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        summaryLabel.alignment = .left
    }

    private func setupToolbar() {
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

    private func setupTable() {
        // Checkbox column
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

        // Path column
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

        // Context menu
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

    private func setupStatusBar() {
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        deleteButton.bezelStyle = .rounded
        deleteButton.setButtonType(.momentaryPushIn)
        deleteButton.isEnabled = false
    }

    private func layoutSubviews() {
        let views: [NSView] = [
            summaryBar, summaryLabel, tabControl, thresholdLabel,
            thresholdPicker, scrollView, statusLabel, scanButton,
            cancelButton, deleteButton
        ]
        for v in views {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        let pad: CGFloat = 12
        let smallPad: CGFloat = 8

        NSLayoutConstraint.activate([
            // Summary bar
            summaryBar.topAnchor.constraint(equalTo: view.topAnchor, constant: pad),
            summaryBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            summaryBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            // Summary label
            summaryLabel.topAnchor.constraint(equalTo: summaryBar.bottomAnchor, constant: 4),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            // Tab control + Scan button row
            tabControl.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: smallPad),
            tabControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            scanButton.centerYAnchor.constraint(equalTo: tabControl.centerYAnchor),
            scanButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            cancelButton.centerYAnchor.constraint(equalTo: tabControl.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: scanButton.leadingAnchor, constant: -smallPad),

            // Threshold row
            thresholdLabel.topAnchor.constraint(equalTo: tabControl.bottomAnchor, constant: smallPad),
            thresholdLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            thresholdPicker.centerYAnchor.constraint(equalTo: thresholdLabel.centerYAnchor),
            thresholdPicker.leadingAnchor.constraint(equalTo: thresholdLabel.trailingAnchor, constant: 4),

            // Table (scrollView)
            scrollView.topAnchor.constraint(equalTo: thresholdLabel.bottomAnchor, constant: smallPad),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),

            // Status bar row
            statusLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: smallPad),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            statusLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -smallPad),

            // Delete button
            deleteButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            deleteButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -pad),

            // Table height fills remaining space
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -smallPad),
        ])
    }

    // MARK: - Actions

    private func wireActions() {
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

    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        showingFiles = sender.selectedSegment == 1
        checkedURLs.removeAll()
        updateDeleteButton()
        tableView.reloadData()
    }

    @objc private func thresholdChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0 && idx < thresholdOptions.count else { return }
        let newThreshold = thresholdOptions[idx].bytes
        scanner.setMinimumFileSize(newThreshold)
        filterAndReload()
    }

    @objc private func scanTapped(_ sender: Any?) {
        checkedURLs.removeAll()
        scanner.startScan()
    }

    @objc private func cancelTapped(_ sender: Any?) {
        scanner.cancel()
    }

    @objc private func deleteTapped(_ sender: Any?) {
        guard !checkedURLs.isEmpty else { return }
        let count = checkedURLs.count

        let alert = NSAlert()
        alert.messageText = "Move \(count) item\(count == 1 ? "" : "s") to Trash?"
        alert.informativeText = "You can recover them from Trash later."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let urls = Array(checkedURLs)
        scanner.deleteItems(urls)
        checkedURLs.removeAll()
        updateDeleteButton()
    }

    @objc private func revealInFinder(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0 else { return }
        let url: URL
        if showingFiles {
            guard row < displayedFiles.count else { return }
            url = displayedFiles[row].url
        } else {
            guard row < displayedFolders.count else { return }
            url = displayedFolders[row].url
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func checkboxToggled(_ sender: NSButton) {
        let row = sender.tag
        let url: URL
        if showingFiles {
            guard row < displayedFiles.count else { return }
            url = displayedFiles[row].url
        } else {
            guard row < displayedFolders.count else { return }
            url = displayedFolders[row].url
        }
        if sender.state == .on {
            checkedURLs.insert(url)
        } else {
            checkedURLs.remove(url)
        }
        updateDeleteButton()
    }

    // MARK: - Data updates

    private func handleScannerUpdate() {
        // Only re-read disk info on state transitions, not on every progress tick
        if !scanner.scanState.isScanning {
            updateSummary()
        }
        updateStatusBar()
        filterAndReload()
    }

    private func updateSummary() {
        if let info = try? DiskInfo.readBootVolume() {
            summaryBar.doubleValue = info.usedFraction * 100
            summaryLabel.stringValue = "\(info.formattedFree) free of \(info.formattedTotal)"
        }
    }

    private func updateStatusBar() {
        switch scanner.scanState {
        case .idle:
            statusLabel.stringValue = "Ready"
            scanButton.isEnabled = true
            cancelButton.isHidden = true
        case .scanning(let count):
            let formatted = NumberFormatter.localizedString(
                from: NSNumber(value: count), number: .decimal
            )
            statusLabel.stringValue = "Scanning: \(formatted) items..."
            scanButton.isEnabled = false
            cancelButton.isHidden = false
        case .done(let fileCount, let folderCount):
            statusLabel.stringValue = "Done — \(folderCount) folders, \(fileCount) large files"
            scanButton.isEnabled = true
            cancelButton.isHidden = true
        }
    }

    private func filterAndReload() {
        let threshold = scanner.minimumFileSize
        // Client-side filter: raising threshold hides files; lowering requires re-scan
        displayedFiles = scanner.largeFiles.filter { $0.size >= threshold }
        displayedFolders = scanner.largeFolders

        // Remove stale checked URLs that are no longer in displayed results
        let validURLs = Set(displayedFiles.map(\.url)).union(displayedFolders.map(\.url))
        checkedURLs.formIntersection(validURLs)
        updateDeleteButton()

        tableView.reloadData()
    }

    private func updateDeleteButton() {
        let count = checkedURLs.count
        deleteButton.isEnabled = count > 0
        if count > 0 {
            deleteButton.title = "Move to Trash (\(count))"
        } else {
            deleteButton.title = "Move to Trash"
        }
    }

    // MARK: - NSTableViewDataSource

    public func numberOfRows(in tableView: NSTableView) -> Int {
        showingFiles ? displayedFiles.count : displayedFolders.count
    }

    // MARK: - NSTableViewDelegate

    public func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard let columnID = tableColumn?.identifier.rawValue else { return nil }

        let url: URL
        let size: String
        let path: String

        if showingFiles {
            guard row < displayedFiles.count else { return nil }
            let item = displayedFiles[row]
            url = item.url
            size = item.formattedSize
            path = item.displayPath
        } else {
            guard row < displayedFolders.count else { return nil }
            let item = displayedFolders[row]
            url = item.url
            size = item.formattedSize
            path = item.displayPath
        }

        let id = tableColumn!.identifier

        switch columnID {
        case "check":
            let checkbox = (tableView.makeView(withIdentifier: id, owner: nil) as? NSButton)
                ?? {
                    let btn = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxToggled(_:)))
                    btn.identifier = id
                    return btn
                }()
            checkbox.tag = row
            checkbox.state = checkedURLs.contains(url) ? .on : .off
            return checkbox

        case "path":
            let textField = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField)
                ?? {
                    let tf = NSTextField(labelWithString: "")
                    tf.identifier = id
                    tf.font = .systemFont(ofSize: 12)
                    tf.lineBreakMode = .byTruncatingMiddle
                    return tf
                }()
            textField.stringValue = path
            textField.toolTip = url.path
            return textField

        case "size":
            let textField = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField)
                ?? {
                    let tf = NSTextField(labelWithString: "")
                    tf.identifier = id
                    tf.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
                    tf.alignment = .right
                    return tf
                }()
            textField.stringValue = size
            return textField

        default:
            return nil
        }
    }
}
