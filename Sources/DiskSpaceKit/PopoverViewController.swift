import AppKit

@MainActor
public final class PopoverViewController: NSViewController,
    NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {

    let scanner: DiskScanner
    let preferences = Preferences.shared

    // Full Disk Access banner
    let fdaBanner = NSView()
    let fdaLabel = NSTextField(labelWithString: "Full Disk Access needed — scan results are incomplete.")
    let fdaButton = NSButton(title: "Open Settings", target: nil, action: nil)
    var fdaBannerHeight: NSLayoutConstraint?

    // Summary
    let summaryLabel = NSTextField(labelWithString: "")
    let summaryBar = NSProgressIndicator()

    // Toolbar
    let tabControl = NSSegmentedControl(
        labels: ["Folders", "Files", "Cleanup"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    let thresholdLabel = NSTextField(labelWithString: "Min size:")
    let thresholdPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    let sortLabel = NSTextField(labelWithString: "Sort:")
    let sortPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    let searchField = NSSearchField()

    // Table + status
    let scrollView = NSScrollView()
    let tableView = CheckboxTableView()
    let emptyLabel = NSTextField(labelWithString: "")
    let statusLabel = NSTextField(labelWithString: "Ready")
    let scanButton = NSButton(title: "Scan", target: nil, action: nil)
    let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    let deleteButton = NSButton(title: "Move to Trash", target: nil, action: nil)

    // State
    public enum Tab: Int { case folders = 0, files = 1, cleanup = 2 }
    var currentTab: Tab { Tab(rawValue: tabControl.selectedSegment) ?? .folders }

    var checkedURLs: Set<URL> = []
    var displayedFiles: [FileItem] = []
    var displayedFolders: [FolderItem] = []
    var cleanupRows: [CleanupRow] = []
    var searchText = ""

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
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 560))
        setupFDABanner()
        setupSummary()
        setupToolbar()
        setupTable()
        setupEmptyState()
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

        let thresholdIndex = thresholdOptions.firstIndex { $0.bytes == preferences.minimumFileSize } ?? 1
        thresholdPicker.selectItem(at: thresholdIndex)

        if let sortIndex = SortMode.allCases.firstIndex(of: preferences.sortMode) {
            sortPicker.selectItem(at: sortIndex)
        }

        updateFDABanner()
        handleScannerUpdate()
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        updateFDABanner()
    }

    // MARK: - Actions

    @objc func tabChanged(_ sender: NSSegmentedControl) {
        checkedURLs.removeAll()
        updateDeleteButton()
        if currentTab == .cleanup {
            loadCleanup()
        } else {
            filterAndReload()
        }
    }

    @objc func thresholdChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0 && idx < thresholdOptions.count else { return }
        let newThreshold = thresholdOptions[idx].bytes
        scanner.setMinimumFileSize(newThreshold)
        preferences.minimumFileSize = newThreshold
        // Files below the scanned threshold were never collected, so lowering
        // the threshold needs a fresh scan; raising it can filter in place.
        if newThreshold < scanner.scannedThreshold {
            checkedURLs.removeAll()
            startScopedScan()
        } else {
            filterAndReload()
        }
    }

    @objc func sortChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0 && idx < SortMode.allCases.count else { return }
        preferences.sortMode = SortMode.allCases[idx]
        filterAndReload()
    }

    @objc func scanTapped(_ sender: Any?) {
        checkedURLs.removeAll()
        startScopedScan()
    }

    @objc func cancelTapped(_ sender: Any?) {
        scanner.cancel()
    }

    @objc func openFDASettings(_ sender: Any?) {
        DiskAccess.openSettings()
    }

    @objc func deleteTapped(_ sender: Any?) {
        if currentTab == .cleanup {
            performCleanup()
        } else {
            performTrash()
        }
    }

    @objc func rowDoubleClicked(_ sender: Any?) {
        let row = tableView.clickedRow
        guard currentTab == .folders, row >= 0, row < displayedFolders.count else { return }
        // Drill in: scan the chosen folder. Switch scope back via the menu.
        preferences.scanScope = .custom
        preferences.customScanPath = displayedFolders[row].url.path
        checkedURLs.removeAll()
        startScopedScan()
    }

    @objc func revealInFinder(_ sender: Any?) {
        let row = tableView.clickedRow
        guard let url = urlAt(row: row) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc func scanParentFolder(_ sender: Any?) {
        // "Back" from a drill-down: scan the parent, or reset to whole disk
        // once we reach the volume root.
        let volumeRoot = ScanRootResolver.monitoredVolumeURL(preferences: preferences).path
        guard preferences.scanScope == .custom,
              let path = preferences.customScanPath else {
            scanWholeDisk(sender)
            return
        }
        let parent = (path as NSString).deletingLastPathComponent
        if parent == path || parent == "/" || parent == volumeRoot || !parent.hasPrefix(volumeRoot) {
            scanWholeDisk(sender)
        } else {
            preferences.customScanPath = parent
            checkedURLs.removeAll()
            startScopedScan()
        }
    }

    @objc func scanWholeDisk(_ sender: Any?) {
        preferences.scanScope = .wholeDisk
        checkedURLs.removeAll()
        startScopedScan()
    }

    func toggleCheck(forRow row: Int) {
        guard let url = urlAt(row: row) else { return }
        if checkedURLs.contains(url) {
            checkedURLs.remove(url)
        } else {
            checkedURLs.insert(url)
        }
        updateDeleteButton()
        tableView.reloadData(forRowIndexes: IndexSet(integer: row),
                             columnIndexes: IndexSet(integer: 0))
    }

    // MARK: - Column sorting

    public func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let key = tableView.sortDescriptors.first?.key else { return }
        let mode: SortMode
        switch key {
        case "size": mode = .size
        case "date": mode = .date
        case "name": mode = .name
        default: return
        }
        preferences.sortMode = mode
        if let index = SortMode.allCases.firstIndex(of: mode) {
            sortPicker.selectItem(at: index)
        }
        filterAndReload()
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

    // MARK: - Scanning

    private func startScopedScan() {
        scanner.setMinimumFileSize(preferences.minimumFileSize)
        scanner.startScan(rootURL: ScanRootResolver.resolve(preferences: preferences))
    }

    // MARK: - Data updates

    func handleScannerUpdate() {
        if !scanner.scanState.isScanning {
            updateSummary()
        }
        updateStatusBar()

        switch currentTab {
        case .cleanup:
            if !scanner.scanState.isScanning { loadCleanup() }
        case .folders, .files:
            filterAndReload()
        }
    }

    private func updateSummary() {
        let url = ScanRootResolver.monitoredVolumeURL(preferences: preferences)
        guard let info = try? DiskInfo.readVolume(at: url) else { return }
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
        var files = scanner.largeFiles.filter { $0.size >= threshold }
        var folders = scanner.largeFolders

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            files = files.filter { $0.displayPath.lowercased().contains(query) }
            folders = folders.filter { $0.displayPath.lowercased().contains(query) }
        }

        displayedFiles = sortFiles(files)
        displayedFolders = sortFolders(folders)

        let validURLs = Set(displayedFiles.map(\.url)).union(displayedFolders.map(\.url))
        checkedURLs.formIntersection(validURLs)
        updateDeleteButton()
        tableView.reloadData()
        updateEmptyState()
    }

    private func sortFiles(_ items: [FileItem]) -> [FileItem] {
        switch preferences.sortMode {
        case .size: return items.sorted { $0.size > $1.size }
        case .name: return items.sorted {
            $0.displayPath.localizedCaseInsensitiveCompare($1.displayPath) == .orderedAscending
        }
        case .date: return items.sorted { $0.modificationDate > $1.modificationDate }
        }
    }

    private func sortFolders(_ items: [FolderItem]) -> [FolderItem] {
        switch preferences.sortMode {
        case .size: return items.sorted { $0.totalSize > $1.totalSize }
        case .name: return items.sorted {
            $0.displayPath.localizedCaseInsensitiveCompare($1.displayPath) == .orderedAscending
        }
        case .date: return items.sorted { $0.modificationDate > $1.modificationDate }
        }
    }

    func updateFDABanner() {
        let granted = DiskAccess.hasFullDiskAccess()
        fdaBanner.isHidden = granted
        fdaBannerHeight?.constant = granted ? 0 : 40
    }

    func updateDeleteButton() {
        let count = checkedURLs.count
        deleteButton.isEnabled = count > 0
        let verb = currentTab == .cleanup ? "Clean Up" : "Move to Trash"
        deleteButton.title = count > 0 ? "\(verb) (\(count))" : verb
    }

    func updateEmptyState() {
        let isEmpty = numberOfRows(in: tableView) == 0
        emptyLabel.isHidden = !isEmpty
        guard isEmpty else { return }
        if scanner.scanState.isScanning {
            emptyLabel.stringValue = "Scanning…"
        } else if currentTab == .cleanup {
            emptyLabel.stringValue = "No reclaimable locations found."
        } else if !searchText.isEmpty {
            emptyLabel.stringValue = "No items match “\(searchText)”."
        } else if case .idle = scanner.scanState {
            emptyLabel.stringValue = "Click Scan to find large items."
        } else {
            emptyLabel.stringValue = "No items found."
        }
    }

    // MARK: - Helpers

    private func urlAt(row: Int) -> URL? {
        guard row >= 0 else { return nil }
        switch currentTab {
        case .files: return row < displayedFiles.count ? displayedFiles[row].url : nil
        case .folders: return row < displayedFolders.count ? displayedFolders[row].url : nil
        case .cleanup: return row < cleanupRows.count ? cleanupRows[row].target.url : nil
        }
    }

    // MARK: - NSSearchFieldDelegate

    public func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField, field === searchField else { return }
        searchText = field.stringValue
        filterAndReload()
    }
}
