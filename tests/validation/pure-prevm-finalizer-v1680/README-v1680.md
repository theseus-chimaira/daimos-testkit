# v1680: PDP-6 original PREVM idle finalizer, repeated refusal (native PASS)

Date: 2026-11-19. This is a **source-linked PDP-6 native assembler
integration test**, not full physical 48K PI6/terminal acceptance.

`run-v1680.sh` extracts the **original unchanged** `proc_finish_slot`,
`proc_finish_mark_pending_v892`, and `proc_finish_service_v881` from the
current DAIMOS PDP-6 `proc_pdp6.s`. The established v1494 source-linked
fixture supplies its ordinary non-VM dependencies, including session
HUP, TTY, u-area release, zombie notification and process records.
The `vm_space_destroy` fixture *models* MM refusal while a test-only
two-pin value remains set. This is deliberately not represented as an
actual original `mm_pin` or `pdp6_pure_detach_v1609` execution.

The newly executed v1680 test proves:

- The initial original `proc_finish_slot` refuses VM teardown and
  retains the exact original VM extent, process TRANSITION, u-area,
  `FINALIZE+PREVM` marker, saved exit status, and pending retry bit.
- Three more calls to the original idle-stack finalizer continue to
  refuse while the modeled pin remains held, without any early u-area
  release, repeat HUP, lost marker or zombie publication. The original
  VM leaf is called four times in total, never falsely completed.
- A controlled fixture-only pin release lets the fourth idle service
  call commit original VM destruction, clear PREVM, and enter existing
  post-VM u-area retry; two further retries complete exactly one
  zombie publication and cleanup. Further scans are idempotent.
- The original finalizer source is also compiled with a test-only
  mutation replacing `jumpe 1,proc_finish_vm_done` with an unconditional
  jump. The new native test detects and rejects this **premature VM
  success** mutation rather than relying on a static source check.

The original complementary source-linked regressions were rerun:
`daimos-swap-prevm-finalizer-v1494.sh` PASS, including its false-VM
commit mutant; `daimos-reaper-backoff-v1102.sh` PASS, including
16/32/64 retry backoff and four corrupt mutations; and the separate
`pure-terminal-pin-v1680/run-v1680.sh` PASS with the actual original
PACKED terminal leaf, four 1/2-pin refusals, four definite `mm_free`
refusals and executed unsafe pin-guard mutation.

**Limits:** The new finalizer integration models a held VM pin in a
fixture; the separate terminal leaf test uses actual original
`pdp6_pure_detach_v1609` but models release of its MM descriptor.
These two native tests do not yet exercise a complete real 48K guest
whose MM pin is held during original EXIT/WAIT, nor actual PI6 timing,
physical `FINALIZE+PREVM` epochs, restored physical owner tables,
backing-source failure or the continuous 71-write-watch fault trace.
The real physical terminal test remains P1-E release-blocking. No
production DAIMOS code, kernel ABI or permanent RAM was modified.

Run:

    DAIMOS_REPO=<PURE-checkout> PDP10_PREFIX=<prefix> \
        sh tests/validation/pure-prevm-finalizer-v1680/run-v1680.sh
