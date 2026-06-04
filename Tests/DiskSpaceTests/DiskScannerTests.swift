import Testing
import Foundation
@testable import DiskSpaceKit

@Suite("DiskScanner Tests")
struct DiskScannerTests {

    /// Creates a temp directory tree for testing:
    ///   root/
    ///     small.txt        (100 bytes)
    ///     bigfile.dat      (60 MB — above 50 MB threshold)
    ///     subdir/
    ///       medium.dat     (30 MB — below threshold)
    ///       huge.dat       (200 MB — above threshold)
    private func makeTempTree() throws -> URL {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("DiskScannerTest-\(UUID().uuidString)")
        let subdir = root.appendingPathComponent("subdir")
        try fileManager.createDirectory(at: subdir, withIntermediateDirectories: true)

        // small.txt — 100 bytes
        try Data(repeating: 0x41, count: 100).write(to: root.appendingPathComponent("small.txt"))

        // bigfile.dat — 60 MB
        try Data(repeating: 0x42, count: 60_000_000).write(to: root.appendingPathComponent("bigfile.dat"))

        // subdir/medium.dat — 30 MB
        try Data(repeating: 0x43, count: 30_000_000).write(to: subdir.appendingPathComponent("medium.dat"))

        // subdir/huge.dat — 200 MB
        try Data(repeating: 0x44, count: 200_000_000).write(to: subdir.appendingPathComponent("huge.dat"))

        // Resolve symlinks (including /var -> /private/var) to match
        // paths returned by FileManager.enumerator
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard let resolvedPath = realpath(root.path, &buffer) else { return root }
        return URL(fileURLWithPath: String(cString: resolvedPath))
    }

    private func cleanupTempTree(_ root: URL) {
        try? FileManager.default.removeItem(at: root)
    }

    @Test("Scanner finds files above threshold")
    func findsLargeFiles() async throws {
        let root = try makeTempTree()
        defer { cleanupTempTree(root) }

        let scanner = await DiskScanner()
        await scanner.startScan(rootURL: root)

        // Wait for scan to complete
        while await scanner.scanState.isScanning {
            try await Task.sleep(for: .milliseconds(50))
        }

        let files = await scanner.largeFiles
        // Should find bigfile.dat (60MB) and huge.dat (200MB), NOT small.txt or medium.dat
        // Sizes use allocated (on-disk) size which may be slightly larger due to block alignment
        #expect(files.count == 2)
        #expect(files[0].size >= 200_000_000)  // huge.dat first (sorted by size desc)
        #expect(files[1].size >= 60_000_000)   // bigfile.dat second
    }

    @Test("Scanner accumulates folder sizes")
    func accumulatesFolderSizes() async throws {
        let root = try makeTempTree()
        defer { cleanupTempTree(root) }

        let scanner = await DiskScanner()
        await scanner.startScan(rootURL: root)

        while await scanner.scanState.isScanning {
            try await Task.sleep(for: .milliseconds(50))
        }

        let folders = await scanner.largeFolders
        // root folder should have total size >= 100 + 60M + 30M + 200M (allocated sizes may be larger)
        let rootFolder = try #require(folders.first { $0.url.path == root.path })
        #expect(rootFolder.totalSize >= 290_000_100)

        // subdir should have >= 30M + 200M = 230M
        let subFolder = try #require(folders.first { $0.url.path == root.appendingPathComponent("subdir").path })
        #expect(subFolder.totalSize >= 230_000_000)
    }

    @Test("Scanner reports done state with correct counts")
    func reportsDoneState() async throws {
        let root = try makeTempTree()
        defer { cleanupTempTree(root) }

        let scanner = await DiskScanner()
        await scanner.startScan(rootURL: root)

        while await scanner.scanState.isScanning {
            try await Task.sleep(for: .milliseconds(50))
        }

        let state = await scanner.scanState
        if case .done(let fileCount, let folderCount) = state {
            #expect(fileCount == 2)       // 2 files above threshold
            #expect(folderCount >= 2)     // at least root + subdir
        } else {
            #expect(Bool(false), "Expected done state, got \(state)")
        }
    }

    @Test("Scanner cancellation stops scan")
    func cancellationStopsScan() async throws {
        let scanner = await DiskScanner()
        // Scan root / which takes a long time
        await scanner.startScan(rootURL: URL(fileURLWithPath: "/"))

        // Cancel almost immediately
        try await Task.sleep(for: .milliseconds(100))
        await scanner.cancel()

        // Give the cancelled task time to propagate state back to MainActor
        try await Task.sleep(for: .milliseconds(200))

        let state = await scanner.scanState
        switch state {
        case .idle, .done:
            // Expected: either cancelled back to idle, or completed before cancellation
            break
        case .scanning:
            Issue.record("Expected idle or done after cancel, got scanning")
        }
    }

    @Test("Scanner respects custom threshold")
    func respectsCustomThreshold() async throws {
        let root = try makeTempTree()
        defer { cleanupTempTree(root) }

        let scanner = await DiskScanner()
        await scanner.setMinimumFileSize(100_000_000) // 100 MB — only huge.dat qualifies
        await scanner.startScan(rootURL: root)

        while await scanner.scanState.isScanning {
            try await Task.sleep(for: .milliseconds(50))
        }

        let files = await scanner.largeFiles
        #expect(files.count == 1)
        #expect(files[0].size >= 200_000_000)

        // The results record the threshold they were collected at.
        #expect(await scanner.scannedThreshold == 100_000_000)
    }
}
