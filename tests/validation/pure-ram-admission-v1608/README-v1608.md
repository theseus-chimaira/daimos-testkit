# P1-E1 PDP-6 source admission, v1608

Command from daimos-testkit root:

    DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/pure-ram-admission-v1608/run-v1608.sh

This tests an actual source-linked staged v1381 DROP and v1391
bounded FULL restore, with the original MM rebase assembly and storage
state code. The native fixture supplies controlled MM/provider state.
It also includes v1382 resident backing guards for mount 18 and
v1390 shared FULL-image loading. The v1390 historical test source
uses the former decoder entry name, so the test runner supplies
its established four-register adapter to the current v1458 entry;
the original production decoder and KCORE are not altered.

The new source guard refuses all of the following BEFORE any MM
mutation: BACKSTORE enabled, allocated, bitmap present or owned
blocks; active process swap blocks; missing VFS mount slab; zero
mount capacity; missing root; unsupported root provider; wrong
published mount ID; wrong fifth mount-slot bit. The real DROP
caller is checked for unchanged process, MM, code/data and mode.
The v1381 restore and bounded v1391 FULL restore are checked to
retain their original PACKED suffix under source loss, including
TRANSITION for the refused restore.

Terminal discard is also verified to work after source loss.
The temporary compiled mutant removes admission entirely;
the same native executable MUST reject it due to a failed
admission expectation, not an assembler/linker error.

This is an E1 *staging* increment only. It neither links P1-E
into production KCORE nor proves a scheduler, VFS concurrency,
physical no-swap KINIT boot, immutable file-content lifetime or
complete PI6/full-guest reclaim/restore. Those remain mandatory.
