# v1677 native two-owner RAW PURE fault-pressure preflight

Status: preflight only; **not** accepted physical PI6 fault-pressure.

Links the production PDP-6 `proc_pure_service_pdp6_v1612.c`,
`proc_pure_ram_v1381.c`, FULL/PREFIX restoration and original MM PURE
rebase/reexpand assembly with the established v1395/v1658 native
fixtures. Two separate process MM owners, actual RAW suffix rebase,
and real service publication are tested with three second-owner pin
outcomes: normal, unpin committed but error reported, or genuinely
refused unpin. A pinned failed second owner must remain transition-
held, while an independent first owner completes restore/READY_ONCE.
A separately compiled source mutant removing the original exact-MM
pin predicate must fail the same native oracle.

These controlled native MM failure responses are not real hardware PI6
interrupts, not a full scheduler-driven nine-process 48K guest, and
not proof of system-wide persistent failure cleanup. Next: build
physical v1677 error injection around the accepted v1674 PIPE-held
nine-child fixture, preserve original MM/PI6 watches, and run both
GENERAL and STRICT KINIT profiles with exact A/B/C conservation.

Native preflight tested on 2026-11-19 with current source-built PDP-6
KCC and `p10run`, including the original v1654/v1612/v1658 prerequisite
runs. All three two-owner fault cases pass, and the compiled unsafe pin
predicate mutant is rejected specifically by the **new** two-owner
case (guest exit `000000002202`) with prior baseline tests omitted
from the negative run. No production source or linked KCORE change.

## Source-linked physical PDP-6 lost-success experiment (in progress)

`make-service-fault-v1677.py` creates a **disposable source copy** of
only the PURE MRES service. After a real successful original RAW DROP,
it returns MM_ERR_BUSY exactly once and increments the MRES-only
`v1677_fault_return_count` word. The real kernel MM and scheduler,
source-identity checks, and process state are unmodified. A lost return
on a committed MM operation must be resolved from the single original
owner/pin state, never by a second fictitious owner.

`build-physical-fault-v1677.sh` builds a 48K GENERAL or STRICT test
image from that source using an isolated `$V1677_BASE` and exact
`$V1677_FIXTURE` pipe-controlled PID1/child. The source override is
relative to the kernel Makefile; it never copies source into DAIMOS.
Optional `V1677_CONTROL_KCORE` requires a byte-identical fixed KCORE.

`run-physical-fault-v1677.sh` runs the ORIGINAL PDP-6 nine-owner
RUN/EXIT/WAIT workload and original 71 physical MM write watches.
Its controller reads the actual patched `proc_swap_reclaim` JRST,
computes the relocated PURE MRES base using the linked function
symbol, reads the new counter word at checkpoint B, and requires the
lost-success fault to have happened **exactly once**. It then requires
original v1673 process/MM/pin state and v1674 full write-event replay
and corruption negatives. Neither this design nor a native preflight
alone establishes physical acceptance; both general and strict guests
must complete and their unmodified ORIGINAL MM results must agree.

For a faster bounded *original checkpoint-state* preflight, set
`V1677_FAST=1` in `run-physical-fault-v1677.sh`. This still requires
real A/B/C physical MM/process/owner snapshots through the original
v1673 verifier, exact runtime MRES relocation and one fault witness,
plus three independent negative witness mutations. It intentionally
skips the expensive 71-write-watch continuous-MM replay. It therefore
cannot replace the full v1677 physical PI6/high-water fault matrix.
After both fast variants PASS, run `compare-fault-v1677.py` with their
build and run directories to prove paired binary/state identity.
