import Testing
@testable import DiskSpaceKit

@Suite("DiskInfo Tests")
struct DiskInfoTests {

    @Test("freeBytes is total minus used")
    func freeBytes() {
        let info = DiskInfo(totalBytes: 500_000_000_000, availableBytes: 142_000_000_000)
        #expect(info.freeBytes == 142_000_000_000)
        #expect(info.usedBytes == 358_000_000_000)
    }

    @Test("usedFraction computes correctly")
    func usedFraction() {
        let info = DiskInfo(totalBytes: 1000, availableBytes: 200)
        #expect(info.usedFraction >= 0.799 && info.usedFraction <= 0.801)
    }

    @Test("usedFraction is 0 when totalBytes is 0")
    func usedFractionZeroTotal() {
        let info = DiskInfo(totalBytes: 0, availableBytes: 0)
        #expect(info.usedFraction == 0)
    }

    @Test("freeFraction computes correctly")
    func freeFraction() {
        let info = DiskInfo(totalBytes: 1000, availableBytes: 200)
        #expect(info.freeFraction >= 0.199 && info.freeFraction <= 0.201)
    }

    @Test("formatted free space shows human-readable GB")
    func formattedFreeSpace() {
        let info = DiskInfo(totalBytes: 500_000_000_000, availableBytes: 142_300_000_000)
        let formatted = info.formattedFree
        // ByteCountFormatter with .file style outputs something like "142.3 GB"
        #expect(formatted.contains("GB"))
    }

    @Test("formatted values for total and used")
    func formattedValues() {
        let info = DiskInfo(totalBytes: 500_000_000_000, availableBytes: 142_300_000_000)
        #expect(info.formattedTotal.contains("GB"))
        #expect(info.formattedUsed.contains("GB"))
    }

    @Test("color is green when more than 20% free")
    func colorGreen() {
        let info = DiskInfo(totalBytes: 1000, availableBytes: 300)
        #expect(info.barColor == .green)
    }

    @Test("color is yellow when 10-20% free")
    func colorYellow() {
        let info = DiskInfo(totalBytes: 1000, availableBytes: 150)
        #expect(info.barColor == .yellow)
    }

    @Test("color is red when less than 10% free")
    func colorRed() {
        let info = DiskInfo(totalBytes: 1000, availableBytes: 50)
        #expect(info.barColor == .red)
    }

    @Test("readBootVolume returns non-zero values")
    func readBootVolume() throws {
        let info = try DiskInfo.readBootVolume()
        #expect(info.totalBytes > 0)
        #expect(info.availableBytes > 0)
        #expect(info.availableBytes <= info.totalBytes)
    }

    @Test("volumeName returns a non-empty string")
    func volumeName() throws {
        let name = try DiskInfo.volumeName()
        #expect(!name.isEmpty)
    }
}
