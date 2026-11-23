# K05 v1848: original PDP-6 PCLK PI6 while FULL source and target are pinned

This strictly testkit-only, source-linked 48K PDP-6 experiment extends
the accepted v1845 real secondary DTC3 source-loss test and the v1847
post-failure KCORE PI6 test. All production KCORE, PURE MRES, MM,
process scheduler, VFS and filesystem code remain unchanged.

**2026-11-23 scoped physical PASS:** the original actual PDP-6 PCLK
PI6 interrupt occurred while both FULL source and destination still
had exactly one live MM pin each, followed by real source loss,
rollback, same-reel recovery, five native WAITs, and HALT PC 0.

## Specific acceptance condition

The original v1845 host controller authenticates the installed PURE
MRES base from the actual source-built KCORE `proc_swap_reclaim` JRST,
then stops at the real original bounded FULL loader entry. The
original source-linked MM descriptor table must show *two distinct*
original slot3 owners, both with exact pin count one:

* PACKED suffix source `111200..120000` octal, type 4.
* Full temporary PROCESS APR `120000..130000` octal, type 1.

Only at this point does v1848 arm a breakpoint at the permanent
KCORE `proc_sched_pi_tick` entry, octal `017205`. If a **real PCLK
interrupt** occurs while original source and destination pins are
still live, the monitor reads its first original `AOS` instruction,
the original PI6 frame's interrupted PC (`pdp10_pi_level6`), live
clock/cooldown/cursor, selected root, slot0 and all current physical
MM extents. It must observe exactly the same two pinned MM owners
and no source or target mutation. The captured original PI6 return PC
must be nonzero, not a self-interruption of the tick dispatcher, and
must identify an executive (not a user-mode) continuation. Its address
is bracketed by the original source-linked MRES symbol map, using the
actual MRES base found through the physical KCORE JRST.

Only AFTER the PI6 evidence does the host disconnect independent
DTC3. The genuine FULL loader must return -4 and perform checked
target rollback retaining the unpinned PACKED source. After the exact
same private reel is reattached, all five original child data/PIPE/
EXIT/WAIT witnesses and HALT at PC 0 must pass. The unmodified v1845
physical MM/owner/recovery verifier remains a prerequisite. Three
independent negative trace mutations must be rejected: a missing PI6
saved-interrupt PC, a fabricated out-of-MRES PC, and a forged missing
temporary PROCESS pin.

The verifier rejects a PI6 tick that occurs only after either pin was
released. This is the central new acceptance difference from v1847.

## Source-built physical evidence

All addresses and words below are octal. The actual source-linked
physical KCORE and PURE module are byte-identical to v1845/v1847.

| Original physical witness | Observed |
| --- | --- |
| Fixed KCORE PI6 handler PC | `017205` |
| Original physical PI6 instruction | `350040024510` (`AOS 1,proc_timer_clock`) |
| `pdp10_pi_level6` saved word | `340000037637` |
| Saved executive interrupted PC | `037637` |
| Actual relocated PURE MRES base | `032417` |
| Relative source-linked interrupted offset | `005220`, bracketed by `vfs_create_op` / `vfs_symlink` |
| Original source at FULL and PI6 | slot3 PACKED `111200..120000`, pin=1 |
| Original target at FULL and PI6 | slot3 PROCESS `120000..130000`, pin=1 |
| Actual PI6 slot / cursor / cooldown | `0` / `3` / `0` |
| Original clock word at PI6 | `057171` |
| Post-DTC3 loss | original loader -4; source exact and unpinned, target absent |
| Same-reel return | four secondary children complete, all five WAITs, HALT PC 0 |

Both original physical MM descriptor arrays at FULL and at PI6 are
equal, including all unrelated children; TSFS ROOT stays unchanged.
The v1845 full acceptance oracle passes on this unmodified trace;
v1848 additionally rejects three executed corrupted physical
transcripts (missing saved PC, non-MRES saved PC, missing target pin).

The original accepted physical image hashes:

* KCORE SHA256: `33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b`
* PURE MRES SHA256: `ad246ce14079a821cd69f4c4f7b7661f5d1a0f58c118bdfa5cfa7adf2b2bfe3f`
* v1848 physical transcript SHA256: `6375e8dc51ef6a9e05edbb2b7c9c5252f8ad8e332e9696a05ffea0495cca195d`

The `dxrcheck -d` IMAGE dump abbreviates source words, so it is not
treated as proof of the interrupted code range. Instead, the
independently captured KCORE reclaim JRST establishes the relocated
PURE base and the full original MRES link map bounds the saved PC.

## Reproduction

Build the unchanged current-source five-child v1845 48K physical
guest and run its independently captured installed-JRST probe as
specified in `pure-k05-secondary-physical-v1845/README-v1845.md`.
Then set these variables in the daimos-testkit directory:

    export DAIMOS_REPO=$HOME/git/DAIMOS
    export PDP10_PREFIX=$HOME/cross
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1848_BUILD=/absolute/path/to/v1845/build
    export V1848_PROBE=/absolute/path/to/v1845/probe.clean
    make test-pure-k05-midfull-pi6-v1848

The independent read-only audit of an already completed physical
trace requires `V1848_WORK` pointing to its own exact evidence
directory:

    make test-pure-k05-midfull-pi6-audit-v1848

Original source-reply loss, persistent foreign MM owner/pin failure,
arbitrary PI6 interleavings and exact continuous peak memory remain
separate release gates. Even an accepted v1848 trace cannot alone
close K05 or enable PURE by default.
