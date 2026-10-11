# D6FS atomic append implementation, October 11, 2026 (v1)

The old kernel captured EOF at `OPEN`, which was unsafe for two concurrently
opened append descriptors. The corrected D6FS path stores append intent in
regular-file descriptor metadata and sends offset `-1` to the D6FS provider.
The serialized provider reads the current FCB size before computing the write
offset, then resizes and writes while holding that provider's existing lock.
The descriptor offset is refreshed from `vfs_stat` after a successful write.

FILE metadata has only nine spare bits. An initial experiment added LH `000004`
as a tenth flag; that bit was **not** cleared by the canonical vnode mask,
changed vnode identity, and failed live append tests. The correction safely
reuses the directory bit for append **only when regular-file state is nonzero**.
Directory checks were updated to discriminate these disjoint cases. This has
no additional per-process descriptor words.

The host source-contract audit checks the dispatch/packing/serialization
invariants. The PDP-6 SIMH runtime probe in `probes/daimos-d6fs-append-runtime-20261011-v1.txt`
passed 5/5: initial write, two successive appends, readback of all three
lines, and clean HALT. The unchanged baseline also passed the same serial
append case. That is **not** deterministic concurrent-open coverage.

A two-background-DSH-worker attempt failed because after launching the first
background group, INIT returned to `LOGIN:`; subsequent probe commands went
to LOGIN. **The same failure occurs on the unmodified baseline kernel.**
A reliable two-writer harness remains needed before declaring actual
concurrency acceptance. The current provider-side serialized design prevents
two D6FS writes from reserving the same EOF position, subject to that test.

This change is specific to D6FS. Other writable providers' O_APPEND semantics,
short writes, power-loss/fault injection, and shutdown read-only-root behavior
remain separate followups.

Additional live regression on a freshly rebuilt disk:
`probes/daimos-d6fs-append-directory-history-20261011-v1.txt` passed
5/5 (directory listing, history file readback, new history append and readback,
clean HALT). The current-source D6FS checker then reported superblock 705,
sequence 3 CLEAN. The same-disk second boot using
`probes/daimos-d6fs-append-reboot-20261011-v1.txt` passed 2/2 and recovered
the historical command.
