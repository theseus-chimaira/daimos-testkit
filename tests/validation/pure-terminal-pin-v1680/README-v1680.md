# v1680: original PDP-6 RAW PACKED terminal pin refusal (native PASS)

Date: 2026-11-19. Native source-linked PDP-6 test only. This does not
claim physical 48K PI6 terminal/VM teardown acceptance.

The test links original `vm_pdp6_swap.c` (common terminal metadata
detach), original `vm_pdp6.s` `vm_space_destroy` leaf, the original
`proc_pure_packed_detach_v1609.s` optional-MRES leaf, and original
`proc_storage_runtime_v30.s`. The v1609 testkit supplies MM/free,
backstore and provider fixture behavior, not a substitute terminal
implementation. All KCC and PDP-6 assembler execution is real.

In two independent cases, the fixture gives the original slot-1 RAW
PACKED MM descriptor exactly one and then two physical pins. The
original `vm_space_destroy` must refuse release *four times* per case
without ever calling `mm_free`, clearing a process transition,
changing its VM APR, source backing/u-area, or publishing RESIDENT.
A second independent slot-2 PACKED MM owner (different physical base)
remains intact throughout all attempted teardown operations. The
fixture then releases the pin, and the original terminal leaf must
free **only** the exact slot-1 owner, publish RESIDENT, clear record
and backing in the original KCORE C path and leave the neighbor
unchanged. A second destroy is idempotent, with no additional free.

A third case makes the original fixture `mm_free` return `MM_ERR_BUSY`
four times *after* exact terminal owner validation. The retained
original PACKED owner, source metadata and neighbor must remain
unchanged on every refusal. A final successful `mm_free` then permits
normal cleanup, demonstrating a different error stage from the pin
predicate. This models a definite no-commit `mm_free` failure, not an
unknown or falsely committed free result.

A separately compiled and executed unsafe PDP-6 assembler mutant
removes the original exact-MM pin guard before `mm_free`. The same
new test refuses this unsafe attempt with native guest exit
`000000001102` (a pinned owner incorrectly reached MM_FREE). The
original v1609 terminal behavior also PASSes unchanged. The pin field
comparison correctly uses the numeric field `meta >> MM_PIN_SHIFT`,
not the boolean `MM_EXTENT_PINNED` predicate.

The native fixture directly updates a descriptor to model the eventual
release of an outstanding pin; it does not execute a real PI6 MM-unpin
interleaving. Full source-linked 48K terminal EXIT/WAIT with a
simulator-held original MM pin, idle-stack terminal retry/backoff,
permanently uncertain owner disposition, failed backing source, and
fault-specific continuous MM write watching are all still OPEN.
No production kernel or MM code or fixed-KCORE word was modified.

Run:

    DAIMOS_REPO=<PURE-source-checkout> \
        sh tests/validation/pure-terminal-pin-v1680/run-v1680.sh

All test sources belong only to daimos-testkit. This is an additive
native preflight, not release acceptance for the full P1-E matrix.
