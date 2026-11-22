# K05 v1808: lost successful restore reply

The v1612 PURE MRES service previously required both `rc == MM_OK` and
a committed RESIDENT state to return `READY_ONCE`. A genuine successful
prefix or FULL restore already atomically publishes the PROCESS owner,
VM base, storage mode, and clears TRANSITION. If the caller loses the
success reply, testing the reply instead of this committed state leaves
the restored process without the dispatch-ready token.

This native source-linked PDP-6 regression runs the original
`proc_pure_restore_v1384` and bounded
`proc_pure_ram_restore_v1391` code, original MM rebase/prefix assembly
and original storage mode runtime. An isolated wrapper replaces only
each completed restore's returned `MM_OK` with `MM_ERR_BUSY`.
The guest independently checks exact unpinned PROCESS ownership,
unaltered writable suffix, original backing release, VM mapping,
cleared TRANSITION and actual scheduler `READY_ONCE`.

The production K05 change removes the redundant return-code test
from the existing strict committed-state success predicate. It adds
no state word, allocator, process flag, kernel resident code, or
new scheduling policy. The existing negative loader-refusal tests
still prevent premature readiness.

An executed negative variant restores the old reply-only check in
a disposable service copy and must fail at an exact guest oracle.
No physical PI6 interrupt interleaving or persistent ambiguous-MM
owner recovery is claimed.
