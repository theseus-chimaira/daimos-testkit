# P1-C v1580: real PDP-6 swap owners during persistent MEMFS HALT

Date: 2026-11-14. Full 128K KCC PDP-6, physical Type-236 AUXSTORE,
two independent cold boots, same retained DR backing, new CPU RAM.
This is an acceptance increment, not complete P1-C closure.

## Test-only setup

`daimos-p1c-swap-snapshot-physical-v1580.sh` copies the exact
production kernel into a unique `$TMPDIR` checkout. Its *only*
snapshot-MRES alteration adds a guard reading the original fixed
KCORE `proc_swap_blocks_used` word after the real entry frame is
saved. If zero, the original snapshot shutdown failure leaf refuses
HALT; if positive, all original snapshot physical writes continue.
No production VM, MM, scheduler, allocator or on-drum code changes.

The existing v1477 two-boot snapshot fixture has a v1580-only
userland mode. The root executable creates its actual MEMFS file
and strict raw-XIP test, appends/checks a real LOGSTORE record and
starts four independently scheduled children with 24K-word private
images. It checks each child's actual PROCINFO scheduler state is
SLEEP, then calls privileged HALT *without first exiting* and without
asking the shell to HALT later. Each child touches both ends of its
image before a long sleep. The MEMFS MRES must find outstanding
process swap blocks on entry or that HALT cannot succeed.

The new physical-media oracle reads complete 128-word, 36-bit
Type-236 drum sectors from the actual selected AUXSTORE descriptor;
the reported region layout is preserved on both boots:

```
BACKSTORE 5770+10000
LOGSTORE 5370+400
CACHESTORE 15770+2010
D6FS 1+5367 SUPER 0/1
```

The original 4,096-word requested MEMFS mount has an **effective**
pool of 3,648 words, recorded in physical v2 snapshot header word 4.
The correct snapshot span is therefore 35 sectors, calculated from
the on-media effective pool: `ceil(pool/128)+5+1`. The header's
relative sectors are octal `07735..07777`, ending exactly at the
BACKSTORE range boundary. The first completed physical guest leaves
248 nonzero sectors below the snapshot reservation. The oracle
validates all words as 36-bit values and refuses overlap between
LOGSTORE and BACKSTORE. Hard-coding the requested 4096-word pool or
38-sector reservation was a test-fixture error, corrected before
final acceptance.

Both cold boots physically HALT with the guarded original snapshot
path, real LOGSTORE APPEND/READ_BLOCK and four sleeping children.
The second boot restores the exact original MEMFS file/XIP contents,
checks and executes the restored XIP, observes the boot-one LOGSTORE
record and appends its own committed record. The host confirms the
AUXSTORE descriptor is byte-identical before and after both boots.

## Evidence boundary

Unlike v1579's native test-double allocation callback, this run
requires actual process-swap ownership when snapshot shutdown starts
on a real full guest, and the process data resides on physical
Type-236 backing. However, `memfs_snapshot_shutdown` still executes
synchronously inside HALT. A sleeping swapped child and positive
swap ownership are NOT proof that another process's PI-driven swap-in
was dispatched between the actual snapshot I/O completions. No
in-flight physical DEVICE/VOLUME controller failure is introduced.

Therefore P1-C remains OPEN for a timed PI/swap-in versus snapshot
physical transfer overlap and remaining mapped DEVICE/VOLUME/PI
failure-and-rollback checks. Production KCORE low end remains
`024364` octal; no installed code, runtime memory or media ABI grows.

Run from daimos-testkit:

```
DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross" \
    sh tests/validation/daimos-p1c-swap-snapshot-physical-v1580.sh
```

The test names and source are versioned. The full guest and all
temporary media stay in `$TMPDIR`; set `V1580_KEEP_WORK=1` to retain
them for exact physical inspection.
