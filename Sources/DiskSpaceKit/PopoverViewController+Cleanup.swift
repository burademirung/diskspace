import AppKit

// Cleanup-tab data loading and the destructive Trash/Clean actions, kept out
// of the main controller to keep it focused.
extension PopoverViewController {

    func loadCleanup() {
        var rows = Cleanup.standardTargets().map { CleanupRow(target: $0, size: 0) }
        let nodeModules = scanner.largeFolders.filter { $0.url.lastPathComponent == "node_modules" }
        rows += nodeModules.map {
            CleanupRow(
                target: CleanupTarget(
                    name: "node_modules", url: $0.url, detail: $0.displayPath, isPermanent: false
                ),
                size: $0.totalSize
            )
        }
        cleanupRows = rows
        checkedURLs.formIntersection(Set(rows.map(\.target.url)))
        updateDeleteButton()
        tableView.reloadData()
        updateEmptyState()
        computeCleanupSizes()
    }

    private func computeCleanupSizes() {
        for index in cleanupRows.indices where cleanupRows[index].size == 0 {
            let url = cleanupRows[index].target.url
            Task.detached {
                let size = Cleanup.directorySize(url)
                await MainActor.run { [weak self] in
                    guard let self,
                          index < self.cleanupRows.count,
                          self.cleanupRows[index].target.url == url else { return }
                    self.cleanupRows[index].size = size
                    if self.currentTab == .cleanup { self.tableView.reloadData() }
                }
            }
        }
    }

    func performTrash() {
        guard !checkedURLs.isEmpty else { return }
        let count = checkedURLs.count

        let alert = NSAlert()
        alert.messageText = "Move \(count) item\(count == 1 ? "" : "s") to Trash?"
        alert.informativeText = "You can recover them from Trash later."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        scanner.deleteItems(Array(checkedURLs))
        checkedURLs.removeAll()
        updateDeleteButton()
    }

    func performCleanup() {
        let selected = cleanupRows.filter { checkedURLs.contains($0.target.url) }
        guard !selected.isEmpty else { return }
        let hasPermanent = selected.contains { $0.target.isPermanent }

        let alert = NSAlert()
        alert.messageText = "Clean \(selected.count) location\(selected.count == 1 ? "" : "s")?"
        alert.informativeText = hasPermanent
            ? "Emptying the Trash is permanent. Other items are moved to the Trash and can be recovered."
            : "Items are moved to the Trash; you can recover them later."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clean")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        for row in selected {
            if row.target.isPermanent {
                try? Cleanup.emptyTrash()
            } else {
                scanner.deleteItems(Cleanup.contents(of: row.target.url))
            }
        }
        checkedURLs.removeAll()
        updateDeleteButton()
        loadCleanup()
    }
}
