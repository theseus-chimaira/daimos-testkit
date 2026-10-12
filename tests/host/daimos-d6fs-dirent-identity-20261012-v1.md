# D6FS real disk directory-identity audit — 2026-10-12 v1

This read-only tool compiles an isolated instrumented copy of the checked
DAIMOS `d6fsck.c` source and emits the actual directory-entry references
for FCB indices 0451/0452, including parent index, slot, cached type and
four packed SIXBIT name words. It also emits final reference and reachable
counts from the normal traversal. No disk bytes are modified.

Preserved post-callback-error SIMH image: FCB 0451 is type 1, size 0,
refs 0, unreachable; FCB 0452 likewise. `d6fsck` reports both as orphaned.
Preserved no-fault control: FCB 0451 is type 1, size 6, refs 1,
reachable; its directory entry is in parent FCB 0 at slot 7, type 1,
name words `164463507750:516364576271:000000000000:000000000000`
(octal). FCB 0452 is free, refs 0, unreachable (as expected).
`d6fsck` reports CLEAN for the control image.

The difference directly establishes absent published directory references
for the two orphaned FCBs, consistent with an ambiguous FCB-creation write
return that skips the directory publication path. It does not prove the
specific triggering write call, nor identify durable transaction boundaries
on actual media, nor justify automatic reclamation after power loss.

Run with `DAIMOS_REPO` and `D6FS_DISK` set to the respective source tree
and preserved read-only test disk directory.
