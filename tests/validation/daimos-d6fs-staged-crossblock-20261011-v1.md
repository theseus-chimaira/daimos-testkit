# D6FS V2 staged growth — cross-block SIMH test (2026-10-11 v1)

The native C99 `/CONFIG/XBLK.TEST` writes a file in three phases: 120 words,
24 words crossing the first 128-word boundary, and another 300 words spanning
additional blocks. It verifies the append descriptor's cursor after each
write, reads back all 444 words, then shuts down normally and checks D6FS.

On the patched kernel the test passed 2/2 SIMH probes and `d6fsck` reported
CLEAN. The preopened-descriptor D6FS native regression also passed 2/2.
An independent two-background-worker append run passed 6/6. HISTFILE
write/readback/HALT passed 3/3 and persisted over a reboot (1/1), with
`d6fsck` CLEAN between boots.

These are successful write-path tests, **not** injected error/power-loss tests.
The staged rollback helper and ambiguous final FCB-commit behavior require
backing-failure injection before V2 ordered growth can be considered
failure-path complete. In-place existing-tail overwrites remain outside
crash-atomic record guarantees; no V3 transaction format was introduced.
