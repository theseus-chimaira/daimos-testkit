# DSH source-audit size and low-memory budget (2026-10-12 v2)

Run with `DSH_DXR=... DSH_MAP=... KCORE_MAP=...
sh tests/validation/daimos-dsh-size-guard-20261012-v2.sh`.

This is a strict no-regression guard for the second easy source-optimization
stage, not a successful 32K-boot acceptance. It checks a maximum DSH image
of **035545 octal words**, BSS of **015241 octal words**, and absence of
the old unused libc helpers. The normal **036000 image gate now passes**.

EXEC reserves 020 octal words of origin and 02000 octal words of stack,
then VM rounds up to a 02000-word aligned physical extent. The optimized
image currently requires 055026 octal words including those reservations,
so it still allocates **056000 octal words**. It needs **01026 octal words
(534 decimal)** less to cross the first VM page boundary at 054000.

With the full-build KCORE end **023610**, KCORE + DSH alone requires
**0101610 octal words**, above the physical 32K limit of 0100000 by
01610 octal words (904 decimal). This excludes process tables, active
filesystem packages and other kernel runtime allocations, so even the
next lower VM allocation is not sufficient evidence for a full 32K boot.

The complete 115-case DSH PDP-6 conformance passed after this stage.
The `tests/validation/daimos-low-memory-boot-v2.sh` test was also run:
PDP-6 32K initializes, reaches LOGIN, but ROOT encounters
`LOGIN: EXEC FAILED`. The low-memory boot acceptance therefore remains OPEN.
