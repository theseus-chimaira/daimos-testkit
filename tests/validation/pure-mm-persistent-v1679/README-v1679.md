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

## Physical 48K repeated-refusal experiment (not yet accepted)

`proc-pressure-v1679.c` is a strictly test-only C89 PID1 derived from
the accepted v1674 deterministic PIPE-held nine-child fixture. After
all nine real children are blocked and the genuine tenth RUN refuses
under APR fragmentation, PID1 makes **two additional native RUN**
attempts with unchanged process ownership, requires both to refuse,
then exposes original CTY barrier B. The same original child has a
canary in its writable suffix and all children EXIT/WAIT after B.

`make-physical-fault-v1679.py` substitutes only a versioned disposable
copy of the original PURE DROP C source. Every rebase attempt for
**slot 2** first pins the real source, then calls the **original PDP-6
MM rebase assembler** with invalid sector geometry. The original
assembler refuses before changing a descriptor. The original C DROP
unpins and keeps the process RESIDENT and retryable; other children
can still become exactly PACKED without extra kernel state.

`host-cty-fault-v1679.py` derives the installed optional PURE MRES
base from the actual permanent `proc_swap_reclaim` JRST and the
source-built MRES map, and requires at least **three actual invalid
MM rebase returns** in its real physical counter at B. It reads the
original A/B/C MM and process snapshots. `measure-v1679.py` adds
exactly two repeated native refused-RUN milestones and uses the
v1678 source-linked eight-PACKED/one-RESIDENT MM/PROC/MEMINFO and
exact C-recovery oracle unchanged. Three corruptions of the original
JRST/MRES counter are rejected, along with two altered repeated RUN
milestones and all five v1678 original MM/PROC/MEMINFO mutations.

Both independent GENERAL/STRICT 48K source images must match in
fixed KCORE and test-only PURE MRES DXR/map. All physical results are
unaccepted until the recorded runs complete, including full EXIT/WAIT
and paired source-linked report comparison. `V1679_FAST=1` intentionally
omits 71 continuous MM write watches; its results cannot establish
the fault-injected intermediate high-water or all PI6 schedules.
The complete original physical MM write-watch test is a separate gate.
