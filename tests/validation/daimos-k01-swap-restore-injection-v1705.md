# K01 v1705 - physical swap-in refusal test source-anchor repair

The v1494 full-system F07 BACKSTORE bitmap-refusal injector targets
the real PDP-6 swap-in release and subsequent failed TERM/PREVM
transaction. Its former `proc_swap_service_failed` anchor assumed
the service delivered TERM immediately after setting the scheduler
cursor. Production v1507 instead writes a bounded per-owner retry
epoch before the `proc_swap_service_failed_event_v1507` label.

The injector now instruments the **post-epoch event boundary**, after
`proc_event_apply`, preserving the original retry/deadline update.
No production DAIMOS source was changed for this test correction.

`daimos-k01-swap-restore-injection-v1705.sh` source-links only the
three production files required by the v1494/v1495 injections, tests
both the bitmap-refusal and diagnostic extensions, proves the v1507
retry/deadline sequence remains intact, and rejects an unsafe mutant
which removes the event label. The existing v1494 final-owner verifier
also rejects all 12 synthetic negative controls.

The v1494 physical guest must pass its *own* full original F07
postflight in addition to the exact bitmap-refusal verification;
preparing, building or booting the guest does **not** count as physical
swap/restore K01 acceptance. Guest evidence is separate from this
fast source-level acceptance check.

The existing local v1494 stack-witness edit (`-3(17)` to `-4(17)`)
preceded this repair and is not included in the v1705 commit. The
v1705 injection test uses the current worktree for that witness,
without silently staging the unrelated edit.
