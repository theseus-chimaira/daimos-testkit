# D6FS intent replay decision matrix — 2026-10-12 v1

This is a **host-only, deliberately conservative** C99 model. It enumerates
three intended durable states (EMPTY, PREPARE, COMMIT) crossed with five
booleans representing surviving child-FCB, child-data, parent-extent,
dirent and parent-size metadata. It is not an implementation of D6FS replay.

Result: 96 combinations enumerated; 87 explicitly require investigation,
one complete COMMIT case permits roll-forward, and eight empty cases
need no action in this simplified model. The empty cases deliberately
exclude child-FCB and directory-entry publication; the model does not
pretend a clear intent proves other untracked allocations are absent.

The model will never free an extent, discard an ambiguous metadata write,
or replay an incomplete COMMIT record automatically. Real recovery needs
persistent identity for target FCB, directory name/slot, and allocations;
it must distinguish already-applied writes, conflicting names and missing
extents. Those fields and the durability ordering must be established before
any kernel change. A checksum-valid COMMIT record by itself cannot establish
that the referenced metadata is intact.

Limitations: combinations are independent booleans, not every physically
reachable write order; there are no torn sectors, write reordering, crashes,
boot replay, byte-level filesystem mutations or SIMH validation. The
ROLLFORWARD result presumes identity checks outside this model. Do not
interpret PASS as proof of atomic create or HISTFILE append.

Build and run:
`cc -std=c99 -O2 -Wall -Wextra -Werror tests/host/daimos-d6fs-intent-replay-matrix-20261012-v1.c -o $TMPDIR/d6fs-replay-matrix && $TMPDIR/d6fs-replay-matrix`
