// scripts/benchmark-scan.swift
//
// Measures filesystem-walk strategies so the scan-speedup ideas from the
// research (docs/RESEARCH-scan-speedup.md) can be validated on real hardware
// BEFORE changing production code. Read-only; deletes nothing.
//
//   swift scripts/benchmark-scan.swift [path]     # default: $HOME
//
// Tip: run `sudo purge` between runs to compare cold-cache numbers, where
// parallelism helps most.
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : NSHomeDirectory())

let keys: Set<URLResourceKey> = [
    .totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey, .contentModificationDateKey
]
let keysArray = Array(keys)

func size(_ values: URLResourceValues) -> Int64 {
    Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
}

/// Mirrors the current scanner: one enumerator, resourceValues per file.
func sequential(prefetch: Bool) -> (files: Int, bytes: Int64) {
    var files = 0
    var bytes: Int64 = 0
    let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: prefetch ? keysArray : nil,
        options: [],
        errorHandler: { _, _ in true }
    )
    while let url = enumerator?.nextObject() as? URL {
        guard let values = try? url.resourceValues(forKeys: keys),
              values.isRegularFile == true else { continue }
        bytes += size(values)
        files += 1
    }
    return (files, bytes)
}

/// Parallelize one sequential walk per top-level subdirectory.
func parallelTopLevel() -> (files: Int, bytes: Int64) {
    let entries = (try? FileManager.default.contentsOfDirectory(
        at: root, includingPropertiesForKeys: [.isDirectoryKey], options: []
    )) ?? []
    let subdirs = entries.filter {
        (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    let lock = NSLock()
    var files = 0
    var bytes: Int64 = 0

    DispatchQueue.concurrentPerform(iterations: subdirs.count) { index in
        var localFiles = 0
        var localBytes: Int64 = 0
        let enumerator = FileManager.default.enumerator(
            at: subdirs[index],
            includingPropertiesForKeys: keysArray,
            options: [],
            errorHandler: { _, _ in true }
        )
        while let url = enumerator?.nextObject() as? URL {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            localBytes += size(values)
            localFiles += 1
        }
        lock.lock()
        files += localFiles
        bytes += localBytes
        lock.unlock()
    }
    return (files, bytes)
}

func clock(_ label: String, _ body: () -> (files: Int, bytes: Int64)) {
    let start = Date()
    let result = body()
    let seconds = Date().timeIntervalSince(start)
    let gb = Double(result.bytes) / 1_000_000_000
    let name = label.padding(toLength: 26, withPad: " ", startingAt: 0)
    print("\(name) \(String(format: "%6.2f", seconds))s   \(result.files) files   \(String(format: "%.1f", gb)) GB")
}

print("Scanning: \(root.path)")
print("Cores: \(ProcessInfo.processInfo.activeProcessorCount)  (run `sudo purge` between runs for cold-cache)\n")
clock("sequential (prefetch)") { sequential(prefetch: true) }
clock("sequential (no prefetch)") { sequential(prefetch: false) }
clock("parallel top-level") { parallelTopLevel() }
