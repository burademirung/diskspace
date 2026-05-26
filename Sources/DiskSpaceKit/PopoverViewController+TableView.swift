import AppKit

struct RowDisplay {
    let url: URL
    let size: String
    let path: String
}

extension PopoverViewController {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        showingFiles ? displayedFiles.count : displayedFolders.count
    }

    public func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard let column = tableColumn,
              let data = rowData(at: row) else { return nil }

        let id = column.identifier
        switch id.rawValue {
        case "check":
            return checkboxCell(id: id, in: tableView, url: data.url, row: row)
        case "path":
            return pathCell(id: id, in: tableView, path: data.path, fullPath: data.url.path)
        case "size":
            return sizeCell(id: id, in: tableView, size: data.size)
        default:
            return nil
        }
    }

    private func rowData(at row: Int) -> RowDisplay? {
        if showingFiles {
            guard row < displayedFiles.count else { return nil }
            let item = displayedFiles[row]
            return RowDisplay(url: item.url, size: item.formattedSize, path: item.displayPath)
        }
        guard row < displayedFolders.count else { return nil }
        let item = displayedFolders[row]
        return RowDisplay(url: item.url, size: item.formattedSize, path: item.displayPath)
    }

    private func checkboxCell(
        id: NSUserInterfaceItemIdentifier,
        in tableView: NSTableView,
        url: URL,
        row: Int
    ) -> NSButton {
        let checkbox = (tableView.makeView(withIdentifier: id, owner: nil) as? NSButton) ?? {
            let button = NSButton(
                checkboxWithTitle: "",
                target: self,
                action: #selector(checkboxToggled(_:))
            )
            button.identifier = id
            return button
        }()
        checkbox.tag = row
        checkbox.state = checkedURLs.contains(url) ? .on : .off
        return checkbox
    }

    private func pathCell(
        id: NSUserInterfaceItemIdentifier,
        in tableView: NSTableView,
        path: String,
        fullPath: String
    ) -> NSTextField {
        let textField = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField) ?? {
            let field = NSTextField(labelWithString: "")
            field.identifier = id
            field.font = .systemFont(ofSize: 12)
            field.lineBreakMode = .byTruncatingMiddle
            return field
        }()
        textField.stringValue = path
        textField.toolTip = fullPath
        return textField
    }

    private func sizeCell(
        id: NSUserInterfaceItemIdentifier,
        in tableView: NSTableView,
        size: String
    ) -> NSTextField {
        let textField = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField) ?? {
            let field = NSTextField(labelWithString: "")
            field.identifier = id
            field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            field.alignment = .right
            return field
        }()
        textField.stringValue = size
        return textField
    }
}
