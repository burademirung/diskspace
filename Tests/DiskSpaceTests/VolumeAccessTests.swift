import Testing
import Foundation
@testable import DiskSpaceKit

@Suite("Volume & Access Tests")
struct VolumeAccessTests {

    @Test("mountedVolumes includes the boot volume")
    func mountedVolumesIncludesBoot() {
        let volumes = DiskInfo.mountedVolumes()
        #expect(!volumes.isEmpty)
        #expect(volumes.contains { $0.url.path == "/" })
    }

    @Test("readVolume returns positive totals for the boot volume")
    func readVolume() throws {
        let info = try DiskInfo.readVolume(at: URL(fileURLWithPath: "/"))
        #expect(info.totalBytes > 0)
        #expect(info.availableBytes >= 0)
        #expect(info.availableBytes <= info.totalBytes)
    }

    @Test("hasFullDiskAccess returns a Boolean without crashing")
    func fullDiskAccessProbe() {
        // We can't assert the value (depends on machine grant), only that the
        // probe completes cleanly.
        _ = DiskAccess.hasFullDiskAccess()
    }
}

@Suite("Display Formatting Tests")
struct DisplayFormattingTests {

    @Test("distantPast modification date formats as empty")
    func emptyDate() {
        let file = FileItem(
            url: URL(fileURLWithPath: "/tmp/x"), size: 100, modificationDate: .distantPast
        )
        #expect(file.formattedDate.isEmpty)

        let folder = FolderItem(url: URL(fileURLWithPath: "/tmp"), totalSize: 100, itemCount: 1)
        #expect(folder.formattedDate.isEmpty)
    }

    @Test("A real modification date formats to a non-empty string")
    func realDate() {
        let file = FileItem(
            url: URL(fileURLWithPath: "/tmp/x"),
            size: 100,
            modificationDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(!file.formattedDate.isEmpty)
    }
}
