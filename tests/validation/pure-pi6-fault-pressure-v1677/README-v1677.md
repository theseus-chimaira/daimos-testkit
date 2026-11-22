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

## 2026-11-19 scoped 48K physical result: PASS

Both original, independently booted GENERAL and STRICT 48K swapless
PDP-6 guests, with *identical* fixed KCORE and a test-only modified
PURE MRES, completed the original 9-child PIPE-held native RUN /
EXIT / WAIT workload. Each actually refused the tenth RUN because
of MM fragmentation, physically showed nine RAW PACKED owners at B,
and recovered the exact original A owner/pin/mode/free state at C.
The original `measure-v1673.py` physical owner and native SYS_MEMINFO
verifier PASSed for both; the paired `compare-fault-v1677.py` also PASSed
with byte-identical original v1673 report SHA256
`7ba78a492c00f4b99f17d8ebecee8e0a170e4907c62424066bd9a08e4db6779a`.

| Original physical MM checkpoint | GENERAL | STRICT |
| --- | ---: | ---: |
| A free / largest | 27332 / 27332 | 27332 / 27332 |
| B free / largest | 2685 / 1532 | 2685 / 1532 |
| C free / largest | 27332 / 27332 | 27332 / 27332 |
| Native failed tenth RUN | 1 | 1 |
| Original RAW PACKED owners at B | 9 | 9 |
| Test-only lost-success return after actual DROP | 1 | 1 |
| Original MM/pin and SYS_MEMINFO physical verifier | PASS | PASS |
| Original JRST/relocated MRES witness + 3 mutants | PASS | PASS |

Original `proc_swap_reclaim` physical address octal `023401` contains
`254000032065` (real installed JRST). Source-linked PURE MRES base
is computed from its original `proc_pure_mres_reclaim_v1612` symbol,
then the isolated fault counter is physically read at octal `035522`
with value `000000000001`, **exactly once** in both independent guests.
The independent negative witness test rejects a zeroed count, a
corrupted original service JRST and a duplicated counter reading.

Fixed KCORE image SHA256 (byte-for-byte v1674 control):
`66296e13440e1f4db3bf263e181dc33e085f55dc4b0f07c09f147e6c1c88b506`.
Test-only PURE MRES image SHA256, identical in both profiles:
`ebb45033ecacb80fb99c783c59ed6ef78ee027f323e9279e8f5c35fc112512c0`.
Unlike the v1674 control PURE module, the versioned injected MRES
requires seven more physically managed words (v1674 A=27339, here
A=27332), not seven added fixed-KCORE words. The control images and
original v1674 results are not overwritten or silently mixed.

**Exact acceptance scope:** ONE test-only lost-success return after
a real, successful RAW suffix MM rebase/unpin; its original process
ownership and bystander restore stay valid throughout normal guest
RUN/EXIT/WAIT. PI6 slot-0 real-interrupt exclusion is separately
accepted by original v1650 native regression and three mutants.
The two full v1677 71-watch diagnostic attempts were terminated
**before B**, retained as diagnostics and never counted as successful.
This fast physical test intentionally has no continuous write-watch
trace; it does not establish the v1677 intermediate high-water,
arbitrary persistent MM failure, genuine faulting PI6 handler
interleaving, source-loss cancellation, or full P1-E acceptance.
All those items remain open in the DAIMOS TODO.
