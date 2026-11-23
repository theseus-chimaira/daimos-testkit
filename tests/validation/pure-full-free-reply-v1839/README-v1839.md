# K05 v1839: bounded FULL restore after a lost source-free return

Run from the daimos-testkit checkout:

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-k05-source-free-native-v1839

The test compiles the current original `proc_pure_ram_restore_v1391.c`
with KCC for PDP-6 and links the original PURE DROP, prefix restore,
MM rebase/claim/release assembler, storage-map assembler and existing
v1384/v1395 process/MM fixture. It first executes the original v1395
failure/rollback suite, then tests three additional source-linked cases.

1. The authoritative PACKED source is successfully freed, but the
   `mm_free` caller sees `MM_ERR_BUSY`. A complete, unpinned PROCESS
   destination is then the sole owner: publish RESIDENT and release
   TRANSITION; do not roll back the only complete APR.
2. The source's `mm_free` genuinely refuses without changing the exact
   owner. Roll back the temporary destination, keep the unpinned source
   and the saved immutable backing, and retain TRANSITION until the
   normal service applies its separately verified retry policy.
3. The source is still present but its owner changes unexpectedly.
   Neither publish RESIDENT nor free the complete destination; retain
   both extents and quarantine TRANSITION.

All cases verify the original mutable suffix, two-bit process mode,
physical owner/type/pin records, saved backing and balanced PI state.
Only the `mm_free` return or the independently tested ownership fault
is injected at the original transaction boundary. No production test
flag or second permanent owner registry is introduced.

Two independently compiled negative controls must fail in a running
native PDP-6 guest at their exact `__test_exit` codes:

* Old unsafe rollback after lost successful source free: octal 03003.
* Ignoring a foreign descriptor at the source base: octal 05002.

This is source-linked native transactional proof, not a claim of a
full-system physical PDP-6 PI6 interruption, controller disappearance,
hardware MM corruption or K05 production acceptance. K05 remains open.
