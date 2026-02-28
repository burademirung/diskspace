import Testing
import Foundation
@testable import DiskSpaceKit

@Suite("ScanTypes Tests")
struct ScanTypesTests {

    // MARK: - FileItem tests

    @Test("FileItem formattedSize returns human-readable string")
    func fileItemFormattedSize() {
        let item = FileItem(
            url: URL(fileURLWithPath: "/Users/test/bigfile.zip"),
            size: 1_500_000_000,
            modificationDate: Date()
        )
        #expect(item.formattedSize.contains("GB") || item.formattedSize.contains("MB"))
    }

    @Test("FileItem displayPath replaces home directory with tilde")
    func fileItemDisplayPath() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let item = FileItem(
            url: home.appendingPathComponent("Documents/big.zip"),
            size: 100,
            modificationDate: Date()
        )
        #expect(item.displayPath.hasPrefix("~/"))
        #expect(item.displayPath.contains("Documents/big.zip"))
    }

    @Test("FileItem displayPath preserves non-home paths")
    func fileItemDisplayPathNonHome() {
        let item = FileItem(
            url: URL(fileURLWithPath: "/Applications/Xcode.app"),
            size: 100,
            modificationDate: Date()
        )
        #expect(item.displayPath == "/Applications/Xcode.app")
    }

    // MARK: - FolderItem tests

    @Test("FolderItem formattedSize returns human-readable string")
    func folderItemFormattedSize() {
        let item = FolderItem(
            url: URL(fileURLWithPath: "/Users/test/Library"),
            totalSize: 28_400_000_000,
            itemCount: 12345
        )
        #expect(item.formattedSize.contains("GB"))
    }

    @Test("FolderItem displayPath replaces home directory with tilde")
    func folderItemDisplayPath() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let item = FolderItem(
            url: home.appendingPathComponent("Library"),
            totalSize: 100,
            itemCount: 1
        )
        #expect(item.displayPath.hasPrefix("~/"))
    }

    // MARK: - ScanState tests

    @Test("ScanState idle is default")
    func scanStateIdle() {
        let state: ScanState = .idle
        if case .idle = state {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected idle state")
        }
    }

    @Test("ScanState scanning carries count")
    func scanStateScanning() {
        let state: ScanState = .scanning(scannedCount: 42000)
        if case .scanning(let count) = state {
            #expect(count == 42000)
        } else {
            #expect(Bool(false), "Expected scanning state")
        }
    }

    @Test("ScanState done carries counts")
    func scanStateDone() {
        let state: ScanState = .done(fileCount: 56, folderCount: 1234)
        if case .done(let files, let folders) = state {
            #expect(files == 56)
            #expect(folders == 1234)
        } else {
            #expect(Bool(false), "Expected done state")
        }
    }
}
