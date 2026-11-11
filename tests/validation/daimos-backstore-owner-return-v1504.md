# v1504: exact physical owning-return TERM consumption after bitmap repair

Date: 2026-11-11. A disposable 256K KCC PDP-6 F07 guest with
the existing v1494 single-bit BACKSTORE corruption ran to genuine
HALT/EXIT. A v1499 source-linked event pre/post observer and new
v1504 owner-side witnesses execute in the copied full KCORE source.
No production kernel behavior, storage format or RAM was modified.

The selected real nonresident DISK owner is slot `010` octal, backed
at block `02350` for `0330` blocks. The guest recorded one bitmap
fault, three matching checked free attempts, and one explicit bit
repair. Prior to fault injection its scheduler showed RUN/no-WAIT,
saved executive PC `340000,,015761` and FD control
`000004,,004010` (TERM already pending). The same pending bit was
present when the owner actually resumed its private executive path.

After the repaired swap-in, the **real** `proc_deferred_term_v970`
was entered exactly once for the selected slot. Its associated
`proc_deferred_commit_v970` consumed the pending fatal event once,
changing FD control from `000004,,004010` to
`000000,,004014`: TERM cleared, fatal-close latch set. The real
`proc_fatal_close_current_v879` then ran once with status `0400001`;
the real `proc_finish_common_v932` ran once with the same status;
and `proc_finish_zombie` published the target exactly once. The
owner's swap-record witness at private return was `037` octal,
not the original `02350,,0330` DISK run, consistent with the
production swap-in's successful resident backing publication.

The per-slot deferred-event recorder observed three deferred-event
entries for slot `010`; the final recorded kind was TERM and its
prior FD-control word already carried TERM. F07's real workload
source sends a TERM to each extra child before waiting for it;
the resulting trace is consistent with one earlier parent TERM and
two coalesced scheduler TERM requests, but does not establish the
identity of each earlier event independently.

Strict `daimos-backstore-owner-return-verify-v1504.py` **PASS**es
on actual map-backed final memory. It requires the unchanged strict
v1503 physical coalescing/bitmap/F07 checks, owner identity, exact
FD-control transition, one private TERM, status, finish and zombie,
and independently rejects **20** mutated owner/evidence fields.
The independent physical v1159 protected owner, v1203 MM peak,
v1205 process slots, v1207 swap-stack and v1349 owner lifecycle
verifiers all separately PASS. Guest F07 milestones: exact 18 RUN
acknowledgments and 18 child reaps; final process-swap/BACKSTORE
allocation counts: 0/0.

The older normal v1336 no-failed-swap-in verifier intentionally
fails this fault-injection guest. It must not be loosened; v1504 is
a separate strict fault-specific repaired-bitmap acceptance.

Evidence hashes from the complete physical guest:

```
addresses          a7c1b547d8950196ae8300cebb566e96b76f0c54bd3052fd3b68790402d027c8
simh.out           c0f2a9e7ad74b15dfa62130a8befb9f07571b543ab17c3192bf3d80e1c37a3a9
simh-sampler.log   3f3762460228fb4208e46919c34fcb9baa89976d7c667dfb8fdfa8296e2b9701
build.log          033887138aa349b41f6d36463b02f5eb39dbb38181e72f518f57ddf60c536467
kcore.map          0327d346b65c04540044ebb7c968f62ff5443f179b46f8edc4170a907cc3148f
```

Run the saved evidence gate:

```
sh tests/validation/daimos-backstore-coalesced-physical-v1503.sh \
    "$EVIDENCE/addresses" "$EVIDENCE/simh.out"
python3 tests/validation/daimos-backstore-owner-return-verify-v1504.py \
    "$EVIDENCE/addresses" "$EVIDENCE/simh.out"
```

To rerun the physical guest, use
`daimos-backstore-owner-return-v1504.sh` with DAIMOS_REPO and
PDP10_PREFIX set. It generates a disposable KCC/256K build, runs
the real F07 workload and verifies owner delivery; the original
normal F07 postflight can still exit nonzero on its intentionally
injected terminal swap-in failures.

**Accepted scope:** one recoverable bitmap fault, coalesced TERM,
repair, real owner-return delivery, private close, one finish/zombie,
exact backing cleanup. **Open:** a permanently irreparable bitmap,
bounded retry/quarantine policy, unrecoverable DEVICE loss, and
remaining distinct mixed-media KCORE feature gates. Do not treat
this repaired-bitmap result as proof of permanent-fault recovery.
