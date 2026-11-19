# P1-E v1642: physical selected-root read loss during FULL reconstruction

Status: original physical 48K PDP-6 fail-stop ACCEPTED 2026-11-17.

The selected TSFS ROOT has a deliberate kernel-wide v1538
fail-stop policy. A genuine failed root operation, after normal
physical Type-551 driver retries, calls the original
`kcore_root_fs_io_failure_v1538` and HALTs. It does NOT return
to the FULL loader and cannot be used to claim user retry or
MM rollback. Such recoverable tests must use a secondary
non-root executable backing filesystem.

This testkit-only read-only simulator experiment replays the
exact accepted v1638 original 48K PDP-6 no-AUX TSFS/PURE
mixed executable guest. Child slot2 has plain PURE and slots
3..7 have original COMPRESSED+PURE `/SYSTEM/COMP`; all six
sleep and become PACKED. The first plain child restores and
releases an aligned APR. The simulator stops at the original
`exec_image_full_bounded_v1391` PC 035252 before it reads the
immutable compressed executable backing. Original source-
linked MM proves the compressed child owns BOTH a pinned RAW
suffix and a pinned, complete independent FULL APR.

Only then, while this original guest is suspended, testkit
DETACHes all three selected root Type-551 reels DTC0/1/2
from the simulator. The tape files themselves are fresh private
copies; the kernel and executable words are unchanged.

    PURE_ROOT_OUTAGE_BUILD_V1642=/path/to/v1638/build \
        sh tests/diagnostics/pure-root-read-outage-v1642/replay-v1642.sh

The replay checks the original source-linked KCORE root
classifier at PC 003761 and the root-specific critical HALT
leaf starting from `kcore_critical_device_lost_v1515` 003773.
It records AC1/AC2 provider and public mount ID and the actual
`vfs_namespace_root` word, proving the failing TSFS read belongs
to the selected namespace root rather than a secondary mount.
It also samples complete MM before the outage and at the
actual root-failure classifier. The expected result is a
terminal ROOT HALT, NOT child `Z`, WAIT cleanup or a retry.

    DAIMOS_REPO=/path/to/DAIMOS \
    PURE_ROOT_OUTAGE_BUILD_V1642=/path/to/v1638/build \
    PURE_ROOT_OUTAGE_TRACE_V1642=/path/to/trace.clean \
        sh tests/diagnostics/pure-root-read-outage-v1642/run-audit-v1642.sh

The test rejects an altered mount-ID witness and a falsified
HALT PC. An unexpected successful return is always a failure.

NOTE: this tests a real Type-551 selected-root outage, which
is terminal by design. A recoverable failed FULL executable
read from SECONDARY filesystem and immutable source unmount
checks remain P1-E acceptance gates. No production edit is
allowed merely to bypass the existing essential-root policy.

## Original physical findings

The unchanged source-built 48K guest reached B/A with six
genuine PACKED child suffix owners, followed by bounded FULL
callback PC 035252. At that instruction original compressed
slot3 held two nonoverlapping MM extents, both pin=1:

| Owner | Physical words (octal) | Type |
|---|---|---|
| 3 | 111000..120000 | PACKED_PROCESS |
| 3 | 120000..130000 | PROCESS full APR |

The simulator then detached ALL three original selected root
members DTC0/DTC1/DTC2, with each `show dtcN` confirming it
was no longer attached. The next genuine TSFS data transfer
reached original `kcore_root_fs_io_failure_v1538` at physical
PC 003761, with AC1=7 (TSFS provider), AC2=1 (public mount).
The original `vfs_namespace_root` matches provider 7/mount 1.
The MM source/destination owners and their pins were still
unchanged at this classifier, as the critical-root operation
must fail-stop before normal PURE transaction rollback.

The normal production v1538 critical service then HALTed at
the root-specific original PC **003776** (`HALT 3776`). No
parent Z/WAIT completion followed, correctly. The simulator
terminated its script normally after examining the HALT word.

The source-linked physical auditor PASSes. Mutations falsely
changing the failing root mount to 7 or the HALT PC by one
instruction are independently rejected. The earlier first
replay reproduced the same classified HALT, but a testkit
indentation error printed only DTC2's detach marker; it was
corrected and the complete physical run was repeated before
acceptance. No production source had to be modified.
