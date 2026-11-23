# K05 v1845: current-source physical secondary DTC3 FULL source loss

This is a versioned, testkit-only PDP-6 48K follow-up to the original
v1643/v1654 DTC3 source-loss experiments and the v1839 bounded FULL
source-free reply correction. It does not modify production KCORE,
the PURE service, MM, VFS or filesystem drivers.

**Status 2026-11-23: source-linked physical PASS, scoped to real
secondary DTC3 failure/return.** K05 remains OPEN for other failures.

## Why a new physical fixture is necessary

The original v1643 six-child test was rebuilt against current DAIMOS
mainline after v1839. It successfully source-built and booted the
original 48K TSFS/PURE system, but its sixth actual RUN refused before
the historical checkpoint (`aaaaa!r` from the guest). The failure is
an admission failure, not evidence about source-loss restoration.

The new guest derives the exact original source from v1643, changing
only `P14_CHILDREN` from six to five. Each child still owns a complete
APR before being blocked by its real PIPE; the first uses the TSFS
root and the remaining four the same genuinely mounted, stamped,
read-only secondary DTC3 filesystem. Parent and child mutable-state
sentinels, exact RUN/BRK/EXIT/WAIT and real extra-RUN refusal remain.
The old six-child trace must never be counted as a v1845 success.

## Build and execute

Run these commands from the daimos-testkit checkout, using the current
DAIMOS mainline and installed source-matched PDP-10 tools:

    export DAIMOS_REPO=$HOME/git/DAIMOS
    export PDP10_PREFIX=$HOME/cross
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    sh tests/validation/pure-k05-secondary-physical-v1845/build-v1845.sh

The build script reports the original v1614 evidence directory. Use
the `build` subdirectory within it as `V1845_BUILD` for the physical
outage/recovery replay:

    export V1845_BUILD=/absolute/path/to/pure-brk-pressure-v1614.XXXXXX/build
    make test-pure-k05-secondary-physical-v1845

After a physical run, its unmodified log and normalized trace can
be independently reaudited without rebooting the system:

    export V1845_WORK=/absolute/path/to/daimos-k05-physical-v1845.XXXXXX
    make test-pure-k05-secondary-audit-v1845

All four DTC media files are copied privately for the preflight and
again for the outage replay. Original source-built `kcore.map`,
`pure-mres-v1612.map` and DXR opcodes must match each other. A short
separate simulator boot first stops at the actual guest pressure
marker, reads the installed `proc_swap_reclaim` JRST from physical
KCORE, and derives the relocated PURE MRES base. The real FULL loader
and service return breakpoints are then resolved from this source-
matched base, map and compiled `PUSHJ` instruction. No historic 48K
MM or fixed KCORE opcode addresses are accepted without verification.

The physical outage replay must independently prove a pinned PACKED
suffix and complete PROCESS target for the same secondary-backed
child at FULL loader entry, a real DTC3 detach, actual original
loader error -4, unchanged RAW suffix and backing owner after the
failed transaction, unpinned PACKED source and freed temporary target.
It reattaches the exact same private DTC3 reel and requires five
native child data/PIPE/EXIT and parent WAIT checks before HALT.
Two forged source-based physical transcripts must be rejected: an
unfreed PACKED pin and a false successful FULL loader return.

This is a bounded physical owner-state test, not a continuous
MM write-watch high-water, live PI6 interrupt-instruction timing,
permanently corrupted MM owner or K05-K09 feature closure.

## Actual source-linked physical result

The unmodified full KCORE and PURE MRES streams are byte-identical
between the independently booted historical six-child admission failure
and revised five-child success. Their SHA256 values are:

* KCORE: `33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b`
* PURE MRES: `ad246ce14079a821cd69f4c4f7b7661f5d1a0f58c118bdfa5cfa7adf2b2bfe3f`

The revised physical 48K baseline completed five native RUNs, a real
refused sixth RUN, both original B/A checkpoints, the original PIPE
token release, all five `w` outputs, all WAITs and HALT at PC 0.
The separate physical source-loss test ran on a fresh private media
copy from this matching image, with these original observations:

| Physical source or owner observation | Value |
| --- | --- |
| Installed KCORE `proc_swap_reclaim` JRST | `024143: 254000032627` |
| Derived runtime PURE MRES base | `032417` |
| Linked, physically executed FULL loader | `036153: 200000000004` |
| Actual service return following FULL | `033067` |
| Packed source, owner 3, at loader entry | `111200..120000`, 1 pin |
| Complete temporary PROCESS, owner 3 | `120000..130000`, 1 pin |
| Detached actual DTC3 before read | Confirmed by SIMH |
| Original FULL loader error after detach | `777777777774` (-4) |
| After failure | Source exact, 0 pins; target freed |
| Reattached media | Same private DTC3 reel |
| Completed after reattach | Four later `w`, all WAITs, `Z`, HALT PC 0 |

Original physical MM (managed-arenas free/largest words, not guest
SYS_MEMINFO or continuous write-watch peaks):

| Snapshot | Free | Largest | MM extents |
| --- | ---: | ---: | ---: |
| B, five PACKED children | 7,391 | 4,702 | 18 |
| A, same five PACKED children | 7,391 | 4,702 | 18 |
| FULL, pinned target/source | 6,886 | 4,702 | 18 |
| Failed loader after cleanup | 10,982 | 4,702 | 17 |
| Z, all children retired | 25,876 | 25,876 | 8 |

The original physical-MM descriptor verifier PASSes all five stages,
including the two simultaneously pinned distinct extents at FULL,
the exact unpinned source after rollback, zero child owner at Z,
unchanged TSFS namespace root and no overlapping extents. The original
guest prints one `w` before the injected loss and four after
reattachment, preserving all five child mutable-suffix witnesses.

Two separate physically sourced transcript mutations are rejected:
forged nonzero PACKED pin after rollback and forged zero loader return.
The first verifier implementation incorrectly required five contiguous
`w` bytes even though the SIMH breakpoints separate the first child
from the remaining four. This test-only oracle error was corrected
after inspecting the unchanged original trace; no physical success
was fabricated or source failure discarded.
