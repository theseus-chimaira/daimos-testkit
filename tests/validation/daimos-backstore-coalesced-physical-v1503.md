# v1503: qualified physical already-pending TERM coalescing

This scoped KCORE feature gate analyzes the completed 256K KCC/PDP-6
F07 v1499 guest. It does **not** change the guest, rebuild an image,
or weaken the normal v1336 requirement of zero fatal swap-in failures.

The v1499 injector recorded each real `proc_swap_service_failed`
invocation's selected owner, saved PC, FD-control pending bits,
scheduler WAIT state, disk VM, finalize marker and actual event
return. These pre/post snapshots do not depend on the v1499 branch
counter guard, whose inverted `SKIPN` polarity was fixed in v1502.
The old branch counters are deliberately **excluded** from v1503.

Both physical TERM calls returned zero and left their target
unchanged. The two identical source-backed entry snapshots show:

| Field | Octal |
|---|---|
| slot | `010` |
| BACKSTORE first/count | `02350` / `0330` |
| process metadata | `156000,,400401` |
| nonresident DISK VM | `066000,,000000` |
| scheduler / WAIT | `200024,,000000` (RUN, no WAIT class) |
| saved PC | `340000,,015715` (executive mode) |
| FD control | `000004,,004010` (TERM already pending) |
| FINALIZE | zero |
| event result | zero |

Production `proc_event_apply` checks already-pending fatal events
before the saved-PC gate. Thus both requests were *coalesced* with
the existing TERM bit; the executive PC independently prohibited
foreign teardown. Neither call should create FINALIZE/PREVM, and
both left original DISK ownership intact. These facts explain the
v1495 missing-immediate-PREVM observation without introducing a
kernel change or bypassing stack safety.

The physical guest injected one bitmap fault, performed three
matching checked release attempts, repaired the deliberately removed
bit and eventually ended with zero process-swap and BACKSTORE blocks.
The real guest printed exactly 18 RUN acknowledgments and 18 reap
markers. Independent physical protected-OOM, MM-peak, process-slot,
swap-stack and owner-lifecycle verifiers also PASS. The strict
normal v1336 verifier intentionally rejects the two induced
terminal swap-in errors, so it remains untouched.

The separate `daimos-backstore-coalesced-physical-v1503.py` rejects
missing/duplicated physical map observations, altered DISK ownership,
missing prior TERM, saved user PC, WAIT-class discrepancy, nonzero
event result, missing HALT/EXIT, backing leaks and malformed F07
milestones. Its synthetic gate rejects **15** negative mutations.
The real completed guest and all 15 mutations PASS this *scoped*
classification.

Evidence SHA256:

```
addresses          22ae34d76680923eb37a5a2ffec84872e940085afa3a24910e835464bb59713e
simh.out           880d48c6d2e1977aea0de1e1eaef67ac8d162edb0f6c7eab317f2ae32c137ae7
simh-sampler.log   d570d24cdcd2b46a37ff4becb019c1e59239aac14a0abce6d67b5378cbac06f1
build.log          7eeb4e00b8d86921b5ad06055f18ed66f1dbe13b191dd53c3caac6a5446a65a5
kcore.map          29e1db2613dc217b7777c290f88b6b38895c3abbff9c7eee3a777418dbd9e92f
```

Run on the physical guest evidence directory:

```
sh tests/validation/daimos-backstore-coalesced-physical-v1503.sh \
    "$EVIDENCE/addresses" "$EVIDENCE/simh.out"
```

**Remaining OPEN:** Demonstrate eventual pending TERM consumption
on the owning return path after physical swap recovery (or actual
PREVM finalization), and safe permanent corrupt-backing handling.
Final zero backing usage and guest reaps do not by themselves prove
the selected TERM was delivered. Do not mark the complete
corrupt-BACKSTORE physical gate accepted based on v1503 alone.
