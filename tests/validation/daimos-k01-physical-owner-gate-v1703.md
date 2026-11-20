# K01 v1703 physical MM owner-refusal acceptance

The gate `daimos-k01-physical-owner-gate-v1703.sh` runs existing
full-system, real-PDP-6 v909/v1101/v1125 fault-injection tests against a
disposable copy of the selected DAIMOS kernel. It never modifies the
production checkout, does not inject forced unpins and does not claim
acceptance from unit-only or preparation-only runs.

## Selected physical tests

| Selection | Injected condition | Acceptance evidence |
| --- | --- | --- |
| `busy` | One permanent real u-area MM pin | `mm_free` consistently returns `MM_ERR_BUSY` (-5); owner and one pin survive; slot-0 retries are bounded; WAIT remains unreaped; a separate user progresses |
| `invalid` | One u-area descriptor receives an incorrect MM owner | `mm_free` consistently returns `MM_ERR_INVAL` (-4); no forced release; `GETTEARDOWN` identifies wrong owner (0402); scheduler and bystander progress |
| `foreign` | Wrong-owner u-area and a distinct permanently held filesystem lease | All invalid-owner constraints plus preservation of the independent provider lease and the runnable bystander |

The existing individual tests verify their own guest counters, exact
failure modes, retained state, expected console sequence and final
explicit guest HALT. The v1703 wrapper requires the corresponding
case-specific PASS witness before recording success. It records the
DAIMOS/testkit Git revisions and retains separate output logs in a
versioned `$TMPDIR` evidence directory; each physical test also retains
its disposable source/image when `KEEP_TEST=1` is selected.

## Running the gate

Set `DAIMOS_REPO`, `PDP10_PREFIX` and optionally `TMPDIR`. To execute
all three distinct full-guest scenarios:

```sh
K01_PHYSICAL_CASE=all sh tests/validation/daimos-k01-physical-owner-gate-v1703.sh
```

Use `K01_PHYSICAL_CASE=busy`, `invalid` or `foreign` for a single
scenario. `K01_PHYSICAL_PREPARE_ONLY=1` validates the input and prints
the selected cases without building or booting any image; it is not
acceptance evidence. An unknown selection and any missing witness fail
closed. Each case is a complete independent guest build.

## Remaining scope

A clean matrix validates the basic permanent u-area MM refusal,
quarantine, bounded retry and independent-user behavior. It is not
proof of every interrupt interleaving at `mm_find_fit`, `mm_free`,
`mm_pin_adjust`, pinned grow/shrink/transfer or `mm_move_extent`.
Those are exercised by the native v1694/v1697-v1702 source-linked
fault-injection tests. Hardware-clock PI6 interleaving and a final
cross-subsystem K01 owner/refusal audit remain separate requirements.

The kernel's retry backoff is bounded in rate (16 to 512 ticks), not
guaranteed to complete under permanent corruption. Its safe operator
policy is offline repair followed by a controlled restart; the gate
never gives permission to release an unproven MM extent.

## v1703 acceptance on DAIMOS f7e8450a (2026-11-20)

The three full-system physical scenarios were executed individually
against production DAIMOS revision `f7e8450a` (v1702). Each guest
used a copied and independently fault-injected kernel, booted to its
explicit HALT, and passed the existing guest-side console/counter
checks. The gate reported PASS for the `invalid` and `foreign` cases;
the original v909 runner reported PASS for the `busy` case before the
new wrapper was committed. This is three individually verified cases,
not a claimed successful `K01_PHYSICAL_CASE=all` invocation.

| Case | Calls | Busy (-5) | Invalid (-4) | Reaper attempts | Faults | Errors | Further evidence |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `busy` (v909) | 7 | 7 | 0 | 6 | 1 | 0 | One retained real pin, unreaped WAIT and runnable bystander |
| `invalid` (v1101) | 7 | 0 | 7 | 6 | 1 | 0 | One wrong-owner mutation, retained u-area, diagnostic 0402 |
| `foreign` (v1125) | 7 | 0 | 7 | 6 | 1 | 0 | Independent FS lease retained, 80 provider waits, live bystander |

The foreign lease was `5 << 18` on initial, MM-refusal and final
inspection, and the final u-area matched the refused physical base.
Every case had zero witness errors. Native v1702 allocator publication,
v1098 pre-VM retry-clock, v1102 reaper backoff and v887 diagnostic
regressions were re-run and passed independently.

The next K01 gates are physical recovery after a *transient* refused
VM/u-area release, qualified PI6 activity while the MM owner is
retained, and a final cross-subsystem source/guest consistency audit.
