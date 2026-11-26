# v1970 native KA10 RC10/RM10 provider

Production 52063b63. Existing v1969 DF10 pair 0150/0151,
PI2 and DRM active request/clock/counters reused. Driver
130 initialized words, zero BSS. No new fixed KCORE or
per-process state. Retains Type236 public service ABI; maps
a 128-word block to two adjacent 64-word RM10 segments,
valid blocks 0..2699; BCD track/segment encoded by native
instructions. Controller DONE and not BUSY, status and
exact completion address required before success. Active
deadline 300 line-clock ticks; STOP then verify not BUSY,
acknowledge and fail before releasing DMA buffer. Other
callers wait on active descriptor's event and retry.
No simulator changes or RD10 support.

Native source-linked test uses actual DF10 at 0150/0151,
PI2, PI6, common storage_request_init and clock router.
Process wait/wakeup are test stubs, not scheduler acceptance.
Read/write at blocks0/29/30/2699 on units0/1; absent unit2,
locked write, invalid block2700, real NXM read, selected
medium removal immediately after DATAO (300 ticks).
All PASS, second DMA pair unchanged; peer read with distinct
128 words after each hardware failure without controller
reset. Test media unchanged except intended writes.

    DAIMOS_REPO=$HOME/git/DAIMOS make test-k17-rm10-v1970

Fresh native 64K KA10 paper-tape builds:
    make -C "$DAIMOS_REPO/system/boot/pdp6" DAIMOS_MACHINE=ka10 ROOT=tape BUILD="$w/tape" image
    make -C "$DAIMOS_REPO/system/boot/pdp6" DAIMOS_MACHINE=ka10 ROOT=disk BUILD="$w/disk" image
    python3 boot-v1970.py "$w/tape" "$w/disk" "$PDP10_PREFIX" "$w/matrix"

All four boot profiles reach INIT; verify VFS provider7/6,
BACKSTORE 0/1024 without RM10, 512 with RM10. Live drum map
400000,,004214, two descriptor reads, zero writes, no
active request, unused pair zero, RM10 images unchanged.
The stock mkauxstore requires an unused D6FS partition
reservation (1+04213); only its AUXSTORE descriptor and
512-block tail are used, not a mounted drum filesystem.
The initial all-zero D6FS region fixture was rejected
before boot. Corrected fixture passes. Default boot.ini
leaves FHA disabled; to opt in replace that line with
set fha enabled, set fha0 rm10, attach -q fha0 IMAGE.
D6FS lowmem selects validated drum BACKSTORE after root
mount, never changes ordinary disk BACKSTORE when absent.

Native KCORE hashes identical to v1969, both roots and
swap workload; matched PDP6 KCORE/KINIT/maps/streams and
Stage1 identical. Earlier unmatched FULL build was not
used for PDP6 identity acceptance. Evidence
$TMPDIR/k17-rm10-v1970.H7ccUx/native-recovery, matrix-r2,
ka-tape, ka-disk, pdp6-matched.

## Full-kernel D6FS plus RM10 swap

Use the unchanged v1955 six-child fixture (INIT/child DXRs);
prepare-v1955.sh in ../disk-swap-k09-v1955 can build it.
Build a KA10 lowmem D6FS image with SYSTEM_INIT_DXR and
SYSTEM_MOUNTALL_DXR set to those exact files, then run:
    sh run-swap-v1970.sh BUILD WORK

Evidence $TMPDIR/k17-rm10-v1970.H7ccUx/swap and ka-swap.
A/B/C MM9/20/8, free43812/1268/43826, bitmap0/64/0.
Slot2 DISK run0..63, 8192-word process; drum reads2/2/66,
writes0/64/64, errors0. Six native canary/token and exact
WAIT checks, both parent pipe FDs closed, exact stable
owners/parent APR restored, no leaked reservation, active
DRM descriptor0 and idle-stack pin only. Physical image
descriptor/reserved region unchanged; backing area changed.
Second DF10 pair unchanged throughout. PID1 success marker
then controlled simulator stop, not guest HALT.
General v1955 disk oracle retains default behavior; original
v1959 disk report reverified byte-identical.
Console SHA256 3ba28db6b422314fb2ee0b50159c9ae5320ec9f307aee5bf27b00908375c46d7.
Report SHA256 76036eb9882fb3a4a6677d25131809d6b1483eb5aba98c86484834b7131ab99e.
All five Stage1 decoder identity checks and embedded KCORE
PASS for both KA10 roots and matched PDP6.

Still open: TSFS+RM10 actual swap, full interactive shell
on all four profiles, concurrent/contended DMA and
full-kernel fault/PI qualification. Native probes use
process wait/wake stubs and representative error points.
