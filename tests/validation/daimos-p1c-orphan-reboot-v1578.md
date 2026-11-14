# v1578 physical orphaned LOGSTORE recovery and committed MEMFS snapshot

Date: 2026-11-14. Two independent 128K KCC/PDP-6 cold boots on one
unchanged physical 8 MiB AUXSTORE DRM236 image. No production changes.

## First cold boot: invalid record deliberately abandoned

The existing v1577 optional-MRES test injection was restricted to
the first boot's uniquely tagged LOGSTORE event (`0157601`). The
injection performs a real 128-word Type-236 physical write containing
the expected LSREC1 magic, sequence, metadata and payload, but a
**zero commit trailer**. The injected return status is negative even
though the intentionally invalid sector was physically written.

The unmodified LOGSTORE append routine does not advance its cursor,
slot, or event on this negative result. The user guest checks STATUS
and reads the damaged sector through normal LOGCTL READ_BLOCK. **It
does not retry**. The ordinary HALT syscall then commits the MEMFS
snapshot and stops the first guest. All original backing images are
retained, not copied into a new filesystem for the second boot.

Before starting that second boot, the host uses the authoritative
`mkauxstore --inspect` output to locate the actual LOGSTORE partition,
then independently decodes all 128 36-bit words of every physical
LOGSTORE slot (little-endian 64-bit host storage, upper 28 bits zero).
It found exactly one matching uncommitted record at physical drum
block `05374` (octal), sequence `3`, matching 36-bit payload and
zero trailer, outside the MEMFS BACKSTORE region. The host verified
that the valid LSREC1 checksum/trailer did NOT match this record.

## Second cold boot: full KINIT recovery

KINIT must ignore the abandoned uncommitted LSREC1, not advance the
producer to the sequence beyond it. The second full guest boots with
fresh CPU RAM on the same persistent media, restores MEMFS XIP/data,
checks that no committed previous-boot event `0157601` exists in the
ring, appends a different uniquely tagged LSREC1 (`0157602`), and
validates its 36-bit physical readback and cursor advance. HALT again
commits MEMFS. The AUXSTORE partition descriptor remains exactly
byte-identical throughout both boots.

The independent final physical image oracle verifies that the next
boot **reused** the old orphan's sector and sequence. In the fixed
test guest, INIT and LOGIN each generate one ordinary log record
before the user test. Thus the physical sectors at `05374` onward
must have valid commit trailers and consecutive sequences `3,4,5`;
the first is no longer the orphan code, and the test's second event
is sequence `5`. A regression that accepts the first boot's invalid
orphan would instead skip a slot and start at sequence `4`.

Both boots completed their guest probes at `STATUS:0`. The physical
orphan and correct re-use are verified from disk bytes independently
of guest messages, not inferred from simulated success alone.

## Negative oracles and limits

Four **executed physical-image mutations** are rejected by the
independent oracle: falsely mark the orphan's replacement as an
accepted old event, alter the reused slot's sequence while keeping a
valid commit trailer, alter the final test event's sequence while
keeping a valid trailer, and clear the final record trailer. Prior
native `daimos-logstore-v1.sh` also passes its recovery/torn-record/
state and tape-drain test on current production source.

The error status is **simulated after a genuine successful Type-236
physical write of a deliberately invalid full sector**. The test
does not prove that the hardware itself tears sectors or generates
this controller error naturally. It also does not establish actual
simultaneous swapped process restoration during HALT. P1-C remains
open for real concurrent swap/commit, DEVICE/VOLUME/PI and natural
controller fault isolation. No fixed KCORE RAM or production optional
MRES size changes; 32K optimization HOLD. The earlier unmodified
v1576 positive LOGSTORE/MEMFS 128K two-cold-boot test was rerun
with the strengthened full-record commit-trailer verifier and PASSed
physical append/readback, previous-record recovery and unchanged
AUXSTORE descriptor.
