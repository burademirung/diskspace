import AppKit

@MainActor
public final class PopoverViewController: NSViewController,
    NSTableViewDataSource, NSTableViewDelegate {

    let scanner: DiskScanner

    // UI elements
    let summaryLabel = NSTextField(labelWithString: "")
    let summaryBar = NSProgressIndicator()
    let tabControl = NSSegmentedControl(
        labels: ["Folders", "Files"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    let thresholdLabel = NSTextField(labelWithString: "Min size:")
    let thresholdPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    let scrollView = NSScrollView()
    let tableView = NSTableView()
    let statusLabel = NSTextField(labelWithString: "Ready")
    let scanButton = NSButton(title: "Scan", target: nil, action: nil)
    let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    let deleteButton = NSButton(title: "Move to Trash", target: nil, action: nil)

    // State
    var showingFiles = false
    var checkedURLs: Set<URL> = []
    var displayedFiles: [FileItem] = []
    var displayedFolders: [FolderItem] = []

    // Threshold options in bytes
    let thresholdOptions: [(label: String, bytes: Int64)] = [
        ("10 MB", 10_000_000),
        ("50 MB", 50_000_000),
        ("100 MB", 100_000_000),
        ("500 MB", 500_000_000),
        ("1 GB", 1_000_000_000)
    ]

    public init(scanner: DiskScanner) {
        self.scanner = scanner
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 520))
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

    // MARK: - Actions

    @objc func tabChanged(_ sender: NSSegmentedControl) {
        showingFiles = sender.selectedSegment == 1
        checkedURLs.removeAll()
        updateDeleteButton()
        tableView.reloadData()
    }

    @objc func thresholdChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0 && idx < thresholdOptions.count else { return }
        let newThreshold = thresholdOptions[idx].bytes
        scanner.setMinimumFileSize(newThreshold)
        // Files below the scanned threshold were never collected, so lowering
        // the threshold needs a fresh scan; raising it can filter in place.
        if newThreshold < scanner.scannedThreshold {
            checkedURLs.removeAll()
            scanner.startScan()
        } else {
            filterAndReload()
        }
    }

    @objc func scanTapped(_ sender: Any?) {
        checkedURLs.removeAll()
        scanner.startScan()
    }

    @objc func cancelTapped(_ sender: Any?) {
        scanner.cancel()
    }

    @objc func deleteTapped(_ sender: Any?) {
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

    @objc func revealInFinder(_ sender: Any?) {
        let row = tableView.clickedRow
        guard let url = urlAt(row: row) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc func checkboxToggled(_ sender: NSButton) {
        guard let url = urlAt(row: sender.tag) else { return }
        if sender.state == .on {
            checkedURLs.insert(url)
        } else {
            checkedURLs.remove(url)
        }
        updateDeleteButton()
    }

    // MARK: - Data updates

    func handleScannerUpdate() {
        // Only re-read disk info on state transitions, not on every progress tick
        if !scanner.scanState.isScanning {
            updateSummary()
        }
        updateStatusBar()
        filterAndReload()
    }

    private func updateSummary() {
        guard let info = try? DiskInfo.readBootVolume() else { return }
        summaryBar.doubleValue = info.usedFraction * 100
        summaryLabel.stringValue = "\(info.formattedFree) free of \(info.formattedTotal)"
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

    func filterAndReload() {
        let threshold = scanner.minimumFileSize
        // Client-side filter for raising the threshold; lowering triggers a
        // re-scan in thresholdChanged (smaller files were never collected).
        displayedFiles = scanner.largeFiles.filter { $0.size >= threshold }
        displayedFolders = scanner.largeFolders

        // Remove stale checked URLs that are no longer in displayed results
        let validURLs = Set(displayedFiles.map(\.url)).union(displayedFolders.map(\.url))
        checkedURLs.formIntersection(validURLs)
        updateDeleteButton()

        tableView.reloadData()
    }

    func updateDeleteButton() {
        let count = checkedURLs.count
        deleteButton.isEnabled = count > 0
        deleteButton.title = count > 0 ? "Move to Trash (\(count))" : "Move to Trash"
    }

    // MARK: - Helpers

    private func urlAt(row: Int) -> URL? {
        guard row >= 0 else { return nil }
        if showingFiles {
            return row < displayedFiles.count ? displayedFiles[row].url : nil
        }
        return row < displayedFolders.count ? displayedFolders[row].url : nil
    }
}
