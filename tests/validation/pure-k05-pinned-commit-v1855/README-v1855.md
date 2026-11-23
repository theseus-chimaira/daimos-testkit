# K05 v1855: exact pinned FULL commit and persistent allocator refusal

Date: 2026-11-23. Source-linked KCC PDP-6 native PASS, including
executed original unsafe source and two independently compiled mutants.
This is a real production PURE MRES correctness fix, not a new
permanent KCORE registry, resident process word or opt-in default.

## The reproduced production failure

The original v1839 FULL commit called `mm_unpin(target)`, which
decrements ONE pin and reports success even when another pin remains
on that same extent. It then unpinned and freed the authoritative
PACKED RAW source and could publish a RESIDENT PROCESS APR with an
unexpected live pin. Adding a second actual native MM pin to the
temporary target through the original `mm_pin(base)` during the FULL
loader reproduced the unsafe publication. The original unmodified
production transaction failed the new oracle at PDP-6 native exit
`000000002002` (octal); this is an executed regression, not a code
inspection or unexecuted build failure.

## Corrected transaction

After the FULL loader has completed and the original mutable suffix
is overlaid, the existing PI-excluded commit window checks a SINGLE
authoritative MM owner set. The scan requires an exactly matching
PACKED RAW source and a separate complete PROCESS target, both
owned by the original slot, both with their original exact sizes,
and **each pinned exactly once**. A duplicate, foreign owner,
changed geometry, missing owner or pin count other than one returns
`MM_ERR_BUSY` while TRANSITION and BOTH original reservations remain
held. There is no attempt to guess which pin belongs to whom or to
free a potentially unique memory owner. Genuine target/source
unpin/free errors continue through the already checked rollback
and v1839 lost-reply paths.

To reduce the optional PURE MRES instruction cost, the original
v1839 post-`mm_free` authoritative owner scan and v1855 precommit
check share one helper. It takes the *expected pin count*: one for
precommit and zero for the late source-free-reply reconciliation.
It preserves original v1839 foreign-owner/sole-target rules and
their two independent native negative mutants.

The matched native KCC PDP-6 standalone FULL assembler listing's
instruction-shaped line count grows from 612 (before correction)
to 649 (shared-scan correction), **+37**. The initial separate-scan
experiment grew to 720 (+108), and was superseded. These are
prelink assembler listing counts, NOT final linked MRES words or
fixed-KCORE RAM growth.

## Native original-source tests

From the daimos-testkit checkout:

    export DAIMOS_REPO=$HOME/git/DAIMOS
    export PDP10_PREFIX=$HOME/cross
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    make test-pure-k05-pinned-commit-native-v1855

The harness compiles original current production DROP, PREFIX and
FULL transactions with native KCC for PDP-6, links actual original
MM PURE assembler and storage-mode runtime, and runs the complete
v1395/v1839 FULL transaction and source-free-reply suite first.
Native MM allocation/pin/free fixtures are used at the call boundary;
this test is NOT a whole-machine physical allocator failure.

Additional v1855 cases:

* Two consecutive exact `MM_ERR_NOMEM` allocator refusals, with
  source retained once and unpinned, saved immutable backing intact,
  no destination APR and balanced PI state. Releasing the fault
  permits complete exact source-to-destination restoration.
* An unrelated PROCESS descriptor owned by another slot, pinned
  once, remains unchanged when a valid FULL target/source pair
  commits and publishes RESIDENT. Foreign bystanders are not
  mistaken for a duplicate owner of the FULL transaction.
* A second unexpected original MM pin is acquired on target OR
  source while the loader runs; neither case can free the RAW source
  or publish a runnable APR, both retain precise owner/pin counts
  and saved backing under TRANSITION, and an unsafe immediate
  second restore call cannot alter either owner or the bystander.
* Two separately compiled production-source mutants run on PDP-6
  and fail at exact exit `000000002002`: deleting the precommit
  check entirely, and weakening the check to allow multiple pins
  while retaining v1839's post-free zero-pin validation.

`make test-pure-k05-source-free-native-v1839` also passes separately
on the corrected production source, including its executed
old-destructive-rollback (`000000003003`) and foreign-source-owner
(`000000005002`) negative controls.

## Scope

The native test uses current original FULL transaction source and
real PDP-6 native execution but controlled original MM API fixtures.
It does not prove whole-machine physical pin corruption, independent
bystander scheduler progress, KA10, all PI6 interleavings or optional
PURE production enablement. K05-K09 remain OPEN.

## Independently completed 48K source-built normal-run gate

The original v1845 source-matched five-child builder was rerun after
the v1855 production correction with 48K PDP-6, TSFS root, one
root-backed plain and four secondary-DTC3 compressed PURE children.
Original physical RUN/PIPE/writable-data/EXIT/WAIT guest output was:

    aaaaax[B013060/043565]<010000+010000>[A013060/043565]{013060-013060}LwwwwwZ
    HALT instruction, PC: 000000

The source-built simulator returned zero and the lifecycle runner
printed `PASS lifecycle: physical 48K source-checked PIPE/WAIT/EXIT`.
Physical evidence is preserved in versioned testkit scratch
`$TMPDIR/pure-brk-pressure-v1614.qnobNT/`, with original
`console.clean` SHA256
`c090f8c2aa9475d876286f37c7cd6ab036a4f77b64353730f98a785c95335c8e`.

The fixed KCORE DXR is byte-identical to the previously accepted
v1845-v1848 image (SHA256
`33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b`).
Linked optional PURE MRES image size increases `004000` -> `004027`
octal (+23 decimal words), BSS unchanged at zero; the physical
guest-reported memory accounting increases by exactly the same
`000027` octal. New PURE DXR SHA256
`a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd`.

This physical PASS concerns **ordinary restored execution**. It does
NOT inject an extra physical pin or prove full-system persistence of
unknown MM owner faults. Those are still separate K05 acceptance
requirements, as is production PURE enablement.
