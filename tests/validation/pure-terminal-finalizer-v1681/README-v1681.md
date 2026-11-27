# v1681 source-linked PDP-6 terminal FINALIZE+PREVM integration

Status 2026-11-19: **native original-instruction PASS**, four executed
unsafe-source mutants rejected. This is not full physical 48K/PI6
terminal failure acceptance and does not close P1-E.

## Exact original code executed

The versioned `build-native-v1681.py` extracts source-checked unmodified
original instructions from:

- `proc_pdp6.s`: `proc_finish_slot`, `proc_finish_service_v881`,
  `proc_finish_mark_pending_v892`, and
  `proc_finish_backoff_advance_v885`.
- `vm_pdp6.s`: `vm_space_destroy`.
- `mm_pdp6.s`: `mm_pin`, `mm_unpin`, `mm_free`, `mm_find_base` and
  `mm_delete`.
- `proc_pure_packed_detach_v1609.s`: the complete RAW terminal leaf.
- `vm_pdp6_swap.c`: KCC-compiled permanent `proc_swap_detach`.
- `proc_storage_runtime_v30.s`: original PACKED/RESIDENT mode checks.

Source extraction checks unique real boundaries and fails if those
boundaries move. The original v881 test fixture supplies process/u-area,
RUNQ/TTY/HUP and finalizer-service environment, but the VM terminal,
MM pin/unpin/free and mode publication code are **not fixture copies**.
The native fixture excludes FILE descriptors and absent VFS providers,
which are irrelevant to the checked RAW suffix terminal path.

The test constructs a process in slot 2 with exactly one RAW PACKED
MM descriptor, correct executable-backing identity, intact u-area,
absent resident APR and original mode 2. It calls the **original MM
`mm_pin` instruction** on the physical suffix base. A foreign
`proc_finish_slot` must fail without releasing MM ownership, and set
an exact `FINALIZE+PREVM` pending marker and the original exit status.
The actual idle finalizer scans the marked owner and retries, but
cannot free the pinned extent. The original shared timer/backoff
algorithm is invoked and must advance its delay from octal `020` to
`040` rather than allowing repeated immediate retries.

The test then calls the **original MM `mm_unpin` instruction**, checks
that only the pin field changed and invokes the original idle finalizer
again. The original RAW terminal deletes its exact MM descriptor and
publishes RESIDENT, permanent KCORE detach clears the original swap
record and u-area backing, and `vm_space_destroy` publishes `VM_NONE`.
The existing v881 u-area MM fixture refuses two subsequent u-area
release attempts before allowing the final zombie. Repeated finalizer
scans must not call sleeping HUP again, free MM twice, or publish a
second zombie. Original backoff cleanup clears the pending delay.

## Four executed unsafe original-source negatives

| Test-only mutation | New integrated oracle failure |
| --- | --- |
| Ignore `vm_space_destroy` refusal and commit prematurely | `000000000006` |
| Omit the `PREVM` bit from pending-finalizer marker | `000000000006` |
| Suppress the original `mm_pin` increment | `000000000004` |
| Suppress original retry-backoff doubling | `000000000035` |

Each mutation modifies **only a disposable extracted assembler file**.
The same PDP-6 guest test must return the specified, nonzero native
exit code, not merely crash, time out or fail during linking.

Run:

    DAIMOS_REPO=<PURE-source-checkout> \
        sh tests/validation/pure-terminal-finalizer-v1681/run-v1681.sh

The test produces versioned evidence under `$TMPDIR` and neither
modifies nor installs production DAIMOS source.

## Explicit limits

`proc_finish_service_v881` and the actual backoff function are
**called directly by the PDP-6 native fixture**, not scheduled by a
real SIMH PI6 hardware clock. The process is constructed as PACKED by
the fixture, not made PACKED by a complete 48K guest's reclaim pass;
its outstanding pin is added and removed by original MM instructions
but under test-harness timing. User mode, KINIT/MRES relocation, actual
PI6 masks, saved scheduler context, TTY lifecycle, and a permanently
unknown MM pin are not represented by this test. Those remain open
physical integration requirements.

A normal PIPE-held process resumes/restores its APR before executing
EXIT, so the v1674 nine-child normal PIPE-release test does *not*
exercise a PACKED terminal abort. A full physical terminal test must
trigger genuine *foreign* termination of a PACKED process, or a real
RUN-discard/VM owner failure at the right stage, and observe the original
idle-stack finalizer with a truly retained MM pin. Do not inject an
impossible concurrent user execution or claim that the present native
fixture is such a physical test.

All source changes are in the separate daimos-testkit worktree.

## v1987 current-source fixture refresh

The historical extractor omitted the now-required v1937
proc_exec_stack_busy_v1937 symbol. Link its actual production
instructions and reservation-list head. An overlapping stack
reservation must exclude an otherwise unpinned RAW foreign finalizer
before HUP, MM release or TRANSITION publication. The existing pinned
PREVM/backoff and four negative tests still pass. A fifth actual
unsafe stack-guard bypass rejects at native exit040. No production
change. Evidence daimos-pure-terminal-finalizer-v1681.3zLbCj.
