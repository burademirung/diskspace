import Testing
import Foundation
@testable import DiskSpaceKit

@Suite("Cleanup Tests")
struct CleanupTests {

    private func makeTempTree() throws -> URL {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CleanupTest-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 1_000_000).write(to: root.appendingPathComponent("a.bin"))
        try Data(repeating: 0x42, count: 2_000_000).write(to: root.appendingPathComponent("b.bin"))
        let sub = root.appendingPathComponent("sub")
        try fileManager.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(repeating: 0x43, count: 500_000).write(to: sub.appendingPathComponent("c.bin"))
        return root
    }

    @Test("directorySize sums allocated sizes recursively")
    func directorySize() throws {
        let root = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: root) }
        // 1MB + 2MB + 0.5MB = 3.5MB (allocated may be a little larger)
        #expect(Cleanup.directorySize(root) >= 3_500_000)
    }

    @Test("contents lists only immediate children")
    func contents() throws {
        let root = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: root) }
        // a.bin, b.bin, sub  → 3 immediate entries
        #expect(Cleanup.contents(of: root).count == 3)
    }

    @Test("Standard targets are existing directories")
    func standardTargets() {
        for target in Cleanup.standardTargets() {
            #expect(FileManager.default.fileExists(atPath: target.url.path))
        }
    }

    @Test("Trash target is the only permanent one")
    func trashIsPermanent() {
        let permanent = Cleanup.standardTargets().filter { $0.isPermanent }
        #expect(permanent.allSatisfy { $0.url.lastPathComponent == ".Trash" })
    }
}
