# v1944: physical PI6 executable reservation / retirement PASS

2026-11-26. Both orderings passed on the current v1939 production
source, with the two documented disposable v1943 scheduler delays.
No production source change or permanent RAM growth.

The original revised guest-seeding run completed all actual setup
operations (ijkccccccccdsuIE). At the E stop SIMH printed a DTC3
buffer-flush diagnostic between the genuine IE marker and monitor
label. The old controller rejected this valid marker and exited,
rather than continuing the race. E: slot1, MM12, free lease,
zero reservation, published V2 mount 2, media 0100003. Independent
read-only verifier proves same actual volume ID/CLEAN seal and
999 exact compressed executable words in eight owned native blocks.
Seed trace and private reel:
$TMPDIR/pure-k07-race-physical-v1943.ZWOByB/
Trace SHA256:
0c4160eab5ad1cfde49439c9525938ad60c6c260018ef952a19f014fb5951eb4
Reel SHA256:
44e616a50abae9914359552e9cf55152f6250c9ae50dc526d96091d8e260593e

The corrected monitor parser allows only the known SIMH DTC flush
line between marker and label; actual seed trace and three missing/
interrupted-marker negatives pass. The race-only builder uses that
genuinely guest-seeded reel. Its parent setup mounts and stats the
existing executable instead of repeating the already accepted copy.
The original compressed child remains byte-identical; instrumented
KCORE/KINIT/PURE images are byte-identical to the first revised run.
New TSFS image verification PASS (54 files,317 extents). No fabricated
filesystem owner, physical write, scheduler wake or reservation.

    export DAIMOS_REPO=$HOME/git/DAIMOS
    export PDP10_PREFIX=$HOME/cross TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1944_SEED_BUILD=$TMPDIR/pure-k07-race-v1943.ZEw7l7/build
    export V1944_SEED_TRACE=$TMPDIR/pure-k07-race-physical-v1943.ZWOByB
    sh tests/validation/pure-k07-race-v1943/prepare-reuse-v1944.sh

Actual accepted race build:
$TMPDIR/pure-k07-race-reuse-v1944.PC3CXK/build

    export V1943_BUILD=$TMPDIR/pure-k07-race-reuse-v1944.PC3CXK/build
    make test-pure-k07-race-v1943

All twelve ordered physical checkpoints E,D,F,G,S,Q,R,V,M,A,U,Z
and one normal HALT PC000000, simulator exit0.

E -> D: original root 050201000000, media 0100003, epoch2 and
MM12 unchanged. Current slot2 emits D after UNMOUNT refusal.
Parent slot1 SLEEP, u-area 050251, exact two-word reservation
050364 (next=0, vnode=050202000000) within the original private
executive stack. No permanent secondary backing record.
Provider lease 777777777777 (RH nonzero, free). Actual PI6 delta
1476 decimal ticks. The original executable owner scanner is the
relevant mount guard, not merely a busy provider lease.
F: compressed RUN success, secondary backing record slot3,
reservation released. G: both exact WAITs, MM8, no child VM/u-area
or reservation leak.

S/Q/R: original root published. Actual V2 quiescence bit changes
0100003 to 0120003. Q/R same media, root, epoch2, backing records
and full MM12 table; helper slot2 sleeping, no outstanding reservation.
Real RUN refuses; FSINFO refuses both before and after it.
V: helper succeeds in UNMOUNT, root zero, no barrier/fault/armed
bit, epoch3. PI6 delta from S to V 2504 decimal ticks.
Ordinary DTFS retirement leaves the unused media tag 0100003;
unlike D6FS, it does not clear that word. The actual mount root
determines publication. Fresh MOUNT authenticates the media and
overwrites the tag. M: same root/tag republished. A: successful
same-medium compressed RUN, data sentinel and exact WAIT, MM8.
U/Z: final unmount root zero, unused healthy unarmed tag, MM8,
zero reservation, no child owners. PCLK E6471 -> Z27054, delta
20583 decimal ticks. The private DTC3 reel after HALT is byte-
identical to the actual clean seeded input. No production changes.

Verifier corrections are based on original fs_provider_unlock and
vfs_unmount_quiesce_done_v1562/vfs_mount_retire_slot semantics:
only lease RH indicates FREE; ordinary DTFS root is retired while
its harmless unused media tag remains. No acceptance checks of
actual barrier, backing or ownership were removed. Ten altered
accepted-transcript controls reject missing reservation, foreign
vnode, held lease, missing/early-released barrier, early retirement,
missing clock advancement, retained retirement barrier, leaked
reservation and wrong HALT. Six synthetic media-corruption controls
reject payload, header, cycle, name, executable bit and seal damage.
These are verifier negatives, not executed guest fault injection.

    python3 tests/validation/pure-k07-race-v1943/test-trace-v1944.py \
        "$V1943_BUILD" "$TMPDIR/pure-k07-race-physical-v1943.SE6Mwx"

Accepted physical evidence:
$TMPDIR/pure-k07-race-physical-v1943.SE6Mwx/physical.clean
SHA256 6b5691b66f10a81b058a5c6b3b662f27e529f4f8a0bda82bbee0a877833538fd
Disposable KCORE SHA256:
b8ada9dd7624e5fb97e9dafc8484cc166620d1ef2a7414fe2adec8d3952f4e0c
Disposable KINIT words SHA256:
10d4f8ca749d1caab98c0483a53de054023c0badeb6f24bf834e531a62a70ea3
Disposable PURE SHA256:
a4c13054f299235d944b92b920aa0621fa5bf08d55dec5df34d4e7a6787d3a23

Both physical simulator processes ended. K07 physical PI6 admission
race accepted with explicitly widened scheduler windows. Integrated
source loss/replacement and recovery remain OPEN; do not infer
physical media-fault acceptance from the intact-media race.
