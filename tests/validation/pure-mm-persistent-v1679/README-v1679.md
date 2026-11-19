# v1679 persistent original-MM precommit refusal, native preflight

Status: **PASS original source-linked native PDP-6 repeated-refusal
preflight, 2026-11-19**. This remains narrower than full physical
48K PI6 and persistent-MM fault pressure.

`test-native-v1679.c` extends the existing v1678 two-owner production
MM/transaction fixture, calling **real original PDP-6 MM pin/rebase
assembly with invalid geometry** for the second owner's first four
reclaim attempts (three before and one after healthy bystander restore).
Every attempt must leave that RESIDENT source word-for-word intact,
unpinned, TRANSITION-clear, with the correct VM base and storage mode.
The other owner must remain real PACKED, then independently complete
READY_ONCE. Only after lifting the fault may the refused owner perform
its original DROP and FULL RESTORE. Both genuine original MM pin and
precommit rebase refusals are checked; no fake MM success is returned.

The source-linked production MM, PURE service, prefix/FULL and native
KCC/PDP-6 code run unmodified; tests live only in daimos-testkit.
Separate executed negative cases are already present in v1678 and
must also remain passing. Physical 48K persistent MM failure,
terminal failure handling, original PI6 interleavings and source loss
remain unaccepted.

## Executed original-source native result

Both cases passed: original invalid-zero-base `mm_pin` refusal repeated
four times on the second process, and original PDP-6 rebase-geometry
refusal repeated four times after its valid original pin. In both
cases the original assembly ran, every failed attempt preserved the
second owner's word-for-word RESIDENT source, the exact zero-pin MM
descriptor, the original VM/base/mode and clear TRANSITION. The first
owner retained an unpinned exact PACKED suffix and independently
restored through slot-0 READY_ONCE. After lifting the fault, the second
owner correctly reclaimed, restored and re-published READY_ONCE.
Original PI state and balanced disable/restore counts held throughout.

Two separately **compiled and executed unsafe production-source
mutants** were rejected by the new v1679 native oracle at exact guest
exit status. Removing the real rejected-rebase cleanup unpin fails
native case 2 with `000000003201`; incorrectly zeroing the resident
APR base on a clean rejected MM pin fails native case 1 with
`000000003101`. The test includes the existing v1654/v1612 production
FULL/service prerequisites. Reproduction:

    DAIMOS_REPO=<PURE-source-checkout> sh run-v1679.sh

No original production MM or KCORE word was modified. Real 48K
multi-owner repeated failure under PI6/scheduler, failed FULL source
restore, terminal/uncertain-owner policy and continuous original-MM
write-watch remain unaccepted. Do not count this native test as a
physical P1-E release gate.
