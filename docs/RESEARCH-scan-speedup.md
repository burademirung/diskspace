# Research: speeding up the disk scan

Deep, multi-source, adversarially-verified research (18 claims confirmed, 7
killed) into making `DiskScanner` faster on APFS SSDs. Use
`scripts/benchmark-scan.swift` to measure any change on real hardware before
committing — the strongest recommendation across all sources is **measure,
especially cold-cache.**

## Confirmed findings (ranked by value / effort)

### 1. Batch metadata with `getattrlistbulk()` — biggest single-thread win
Per-file `stat`/`lstat` dominates walk CPU. `getattrlistbulk()` returns metadata
for **dozens–hundreds of entries per syscall**. The Rust tool `dumac` measured
**~6.4× `du`** and **~2.58× `diskus`** using it. Cost: a raw C API with manual
buffer parsing from Swift. *One benchmark found it slower than `readdir` — so the
win is workload/hardware-dependent; measure first.*
Sources: [healeycodes/dumac](https://healeycodes.com/maybe-the-fastest-disk-usage-program-on-macos),
[jonnyzzz](https://jonnyzzz.com/blog/2020/08/12/listing-files/),
[tempel.org](http://blog.tempel.org/2019/04/dir-read-performance.html)

### 2. Bounded parallelism — biggest win on a cold cache
APFS takes a **global kernel lock during `readdir`** (rdar://45648013,
re-confirmed M3/M4 in 2024–25), so parallel walks stop scaling past ~4–5 cores
and can spend most CPU in-kernel. `diskus` uses workers = 3×cores **capped 64**.
Parallelize subtree walks (Swift `TaskGroup`/`DispatchQueue.concurrentPerform`),
**start ~8, cap ~64, measure**; gains are largest on the first (cold) scan,
modest when warm. Needs a thread-safe accumulator. Linux/NVMe ">40× scaling"
does **not** transfer to APFS.
Sources: [Szorc/APFS kernel locks](https://gregoryszorc.com/blog/2018/10/29/global-kernel-locks-in-apfs/),
[diskus](https://github.com/sharkdp/diskus),
[parallel-disk-usage](https://github.com/KSXGitHub/parallel-disk-usage)

### 3. Redundant `resourceValues()` — cheap cleanup, measure the win
The current scanner gives the enumerator `includingPropertiesForKeys` (prefetch)
**and** calls `resourceValues(forKeys:)` per file. Foundation may already return
cached values on the second read, so the gain could be small — verifiers left
this an open question. It's a 10-minute change; benchmark it in isolation to see
if it matters before doing heavier work.

### 4. `fts(3)` — simpler low-level alternative to `getattrlistbulk`
A well-regarded BSD traversal API for local APFS/HFS+; less code than the bulk
API, still beats Foundation per practitioners. Not a guaranteed win — measure.

### 5. APFS size semantics (correctness)
The scanner already uses `totalFileAllocatedSize` (correct for *consumed*
space). But APFS **clones share blocks (copy-on-write)**: N clones of an X-byte
file report N·X logical yet consume ~X. Summing allocated sizes up the tree can
overstate reclaimable space. Surfacing both logical and allocated, and noting
snapshots/purgeable, is more honest.
Sources: [Leventhal APFS](https://ahl.dtrace.org/2016/06/19/apfs-part3/),
[eclecticlight](https://eclecticlight.co/2022/12/30/free-space-on-an-apfs-volume-is-an-illusion/)

## Killed claims — do **not** act on these
- "`readdir` is fastest, beating `getattrlistbulk`" — refuted 0-3.
- "Minimizing requested attributes matters; one extra attribute adds >30%" —
  refuted 0-3. **The current 5 keys are fine; don't bother trimming them.**
- "`FileManager.enumerator` is 3–4× slower than C `readdir`" — refuted 1-2.
  Don't write off Foundation's enumerator as the bottleneck.

## Recommended order for `DiskScanner`
1. **Benchmark first** (`scripts/benchmark-scan.swift`, cold cache).
2. Confirm whether the redundant `resourceValues()` matters; drop it if so.
3. Parallelize top-level subtrees (8 → cap 64) with a thread-safe accumulator.
   Biggest cold-scan win, moderate effort.
4. Only if needed: switch traversal to `getattrlistbulk()`. Highest effort,
   highest single-thread potential; benchmark vs the enumerator on your hardware.
5. Account for APFS clones/sparse/snapshots in "reclaimable" totals.

## Caveats
`dumac`'s multipliers are author self-benchmarks (M1 Pro, warm, synthetic) —
directional, not guarantees. The APFS readdir lock and clone/COW behavior are
confirmed by primary sources and still true in 2025. Re-measure on target
hardware before picking the heavy option.
