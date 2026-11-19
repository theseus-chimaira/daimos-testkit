# v1672: real physical post-user PDP-6 PURE RUN/EXIT/WAIT pressure

Accepted DAIMOS parent v1671:
`19a348898044c441e6cd5d2ccbd09d7e8d361d0d`.

## Production bug found and accepted in this stage

The genuine native `sys_meminfo` and `sys_procinfo` counted the
high-half `0777777` of exited zombie `VM_SPACE_NONE=-1` as
262143 user words. Before the correction, a real 48K four-child
RUN/WAIT test printed `PROCESS-WORDS 532246` while two zombies
remained to be reaped. Those words were NOT physically allocated.
The production source now ignores that sentinel in MEMINFO and
reports zero logical VM for PROCINFO zombie, retaining valid
resident/swapped image counts. Four additional native KCORE
instructions, no new data fields. GCC lowmem fixed KCORE end
octal `024076 -> 024102`; KCC FULL `024353 -> 024357`.

`run-meminfo-native-v1672.sh` source-extracts both corrected
real assembler leaves and executes p10run PDP-6 with a mix of
resident, swapped, zombie and free process slots. Two unsafe
source mutations removing each sentinel guard are separately
executed and rejected. All native tests PASS. A source-built
KCC FULL ROOT=auto also links after this fixed assembler change.

## Physical runtime workload (no kernel test hooks)

`run-physical-v1672.sh` builds a tiny C89 test-only PID1
(`proc-pressure-v1672.c`) and assembly SLEEP-then-EXIT child
(`sleep-child-v1672.s`). These replace `/SYSTEM/INIT` and
`/SYSTEM/EXEC/MOUNTALL` ONLY in disposable, independently built
three-member TSFS test images. The original DAIMOS kernel,
PURE MRES, all physical devices and actual native syscall
implementations are used. BITMAP mode3 remains OFF. Four DTC
media are copied per scenario; no DSK/DRM AUXSTORE attached.

Two image configurations (general ROOT=tape/PURE, strict
v1668 swapless-only ROOT=tape/PURE), each executed under actual
SIMH PDP-6 at physical 48K and 64K. The user fixture launches
four real simultaneous children on 48K or seven on 64K, each
retaining a native PID until every EXIT(0) is reaped by WAIT.

**Important SIMH ownership rule:** user virtual PCs overlap
identical numeric KCORE physical instruction PCs, so a raw SIMH
`break USER_SYMBOL` is NOT a valid process checkpoint and was
removed from the test. The executable v1672 uses explicit
test-only CTY input holds `V1672 HOLD A/B/C`. The host sends
Ctrl-E, inspects the original `mm_core_words`, MM extent capacity
and count, original physical arena table, up to 40 two-word
allocated extents and resident immediate, then `go`, then
releases the held PID1 CTY input. The boot script removes its
trailing SIMH `exit` command; otherwise Ctrl-E terminates the
simulator rather than returning to its monitor. This control
protocol itself was experimentally proven independently.

`measure-v1672.py` validates all physical arena and extent
descriptors, sorting, overlap, process APR owner uniqueness,
type, bounds, pins, exact free+allocated MM conservation and
KCORE permanent resident immediate. It separately compares
every native `SYS_MEMINFO` TOTAL, RESIDENT, PROCESS-WORDS and
PROC-SLOTS reading to actual APR size plus 264-word u-area
ownership, catching the zombie accounting bug in the full guest.
The three accepted checkpoints are before RUN, during the
concurrent children, and after each has exited and been WAITed.

`compare-v1672.py` requires three exact physical states at
each memory size, actual live APR owner count, unique owner
identities, no newly pinned extent, a strict owner/word
conservation proof, and EXACT recovery of baseline free MM,
largest free gap, allocated extents and process APR owners.
For both source-matched configurations it requires matching
physical states, not merely similar or nonnegative free counts.

## Accepted results (four full PDP-6 guest runs)

| Core | Image | Free before | Free with children | Free after WAIT |
| --- | --- | ---: | ---: | ---: |
| 48K | General | 27441 | 18193 | 27441 |
| 48K | Strict | 27441 | 18193 | 27441 |
| 64K | General | 43793 | 27609 | 43793 |
| 64K | Strict | 43793 | 27609 | 43793 |

The largest contiguous free extent equals these total free
values in every snapshot. At 48K the MM owner table has
3934->13182->3934 allocated words, 1->5->1 process APR owners
(PID1 plus four live children). At 64K it is
3950->20134->3950, 1->8->1 owners (seven children). Every child
owns a 2048-word APR and a 264-word stable u-area, hence
2312 physical words per child. The pinned 256-word original
kernel dynamic extent is unchanged throughout. The corrected
native SYS_MEMINFO 48K totals report 3336->12584->3336 process
words. The general/strict physical comparison matches exactly:
pruning unused transient disk-swap code does not make runtime
PURE memory smaller after KINIT is discarded.

## Negative acceptance

`run-negative-v1672.sh` mutates one REAL retained 48K physical
console transcript / output report: invalid original arena,
missing CTY release B, forged `free_words` and duplicate APR
owner. Each mutant is actually passed through the ORIGINAL
positive source-map physical MM decoder/comparator; all four
are rejected. The two separate native assembler mutations above
are also rejected. No mocked process lifecycles are accepted.

## Reproduction

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
    DAIMOS_REPO=/path/to/DAIMOS \
      sh tests/validation/pure-runtime-pressure-v1672/run-meminfo-native-v1672.sh
    DAIMOS_REPO=/path/to/DAIMOS \
      sh tests/validation/pure-runtime-pressure-v1672/run-physical-v1672.sh

`V1672_FIXTURE_BUILD`, `V1672_GENERAL_BUILD` and
`V1672_STRICT_BUILD` may point at source-built image/fixture
directories. `KEEP_TEST=1` retains original SIMH transcript,
physical decoders, maps, linked native binaries and MM JSON.
Selected rerun filters `V1672_ONLY_VARIANT=general|strict`
and `V1672_ONLY_CORE=48|64` are smoke tests: the unfiltered
four-way comparator alone supports cross-profile conclusions.

This validates exactly three stable user-memory checkpoints,
NOT a fully continuous post-user physical high-water. Forced
RAW PURE reclaim, compressed bitmap mode3, PI6 interleaving
stress, disk-root physical boot and strict 32K remain OPEN.
