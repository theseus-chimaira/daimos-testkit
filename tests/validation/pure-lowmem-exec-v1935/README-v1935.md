# Destructive low-memory EXEC live identity, v1935

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-lowmem-exec-v1935

The native PDP-6 gate links the actual destructive EXEC transaction,
loader, KCC-compiled proc_swap_attach, reservation list, provider gateway,
file/mount owner scanners and mapping-hold leaves. Controlled allocation,
file I/O, VM destruction and startup callbacks exercise successful PURE
DXR2 load and six failures: lookup, STAT, header, allocation, payload and
startup. Check stable META/SCHED, mapping hold throughout loading,
entry PC, actual packed backing and credential identity, surviving owner
scans, stack balance and retirement of the transient launch copy and
reservation. Four unsafe variants fail native assertions: overwrite live
metadata, clear live u-area during rollback, lose entry PC, omit map hold.

Earlier v1720, v1933, v1934, v1563, v200 and v1719 gates pass. The old
v1720 mocked loader now preserves live metadata and returns AC2 entry;
its fatal negative control checks leaked map hold instead of relying on
obsolete metadata corruption. The new gate tests actual loader rollback
rather than inventing a corrupted META result in the mock.

No complete-guest PI6 or physical I/O acceptance. Compressed and raw-XIP
execution are not covered by the new native DXR2 fixture. Fatal/private
stack lifetime and namespace lookup admission remain separate K07 work.
