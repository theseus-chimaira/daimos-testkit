# DSH HISTFILE locked repair (2026-10-12 v2)

Command: `make test-daimos-dsh-histfile-repair-20261012-v2`, supplying
PDP10_PREFIX and the DAIMOS_REPO path. An isolated DevSpace build also needs
DAS_REPO and KCC_REPO pointing to the actual source checkouts.

The first live PDP-6 SIMH boot seeds `/.DSH_HISTORY` with a complete
9-character `ECHO SAFE` S6REC (three 36-bit words) followed by an incomplete
18-character S6REC header (one word with no payload), then HALTs cleanly.

The second boot enters DSH with the same filesystem. The shell must print
`DSH: HISTFILE TAIL REPAIRED`, recall the valid command with Ctrl-P,
and execute a native checker after recording the checker invocation.
The checker verifies that the resulting file is exactly 11 words:
three for the seed, three for the recall, and five for the verifier command.
It additionally parses all three records to physical EOF without any
malformed or leftover record. HALT and read-only D6FSCK must succeed.

Result: all 5/5 two-boot target probes passed; D6FSCK reported 179196
blocks / 344 FCBs clean, superblock 0670, sequence 5.

The live test proves bounded startup tail repair and ordinary persistence
of subsequent commands, not crash atomicity of metadata or the lock's
behavior under deliberate process interleaving. Subsequent tests should
inject writer lock conflicts, partial write faults and failed truncate,
and re-run the 115-case DSH conformance suite.

The complete existing DSH conformance suite was also run against the same
freshly built DSH image in the test image: 115/115 target probes passed.
DXRCHECK reports 036722 octal image words and 015241 octal BSS words.
