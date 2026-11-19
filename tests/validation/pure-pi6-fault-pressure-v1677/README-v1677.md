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
