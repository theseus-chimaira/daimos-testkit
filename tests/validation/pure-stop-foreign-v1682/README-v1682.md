# v1682 source-linked physical STOPPED-to-PACKED foreign TERM control

Status 2026-11-19: **fixture prepared; physical admission gate not yet
accepted**. This is a prerequisite to the full pinned-owner terminal
fault test, not a claim that v1680/v1681 physical PI6 gates are done.

The accepted v1674 fixture uses nine PIPE-held sleeping children,
all of which have an interruptible private executive read wait.
Original PDP-6 `proc_event_apply` deliberately defers foreign fatal
TERM while such a private kernel stack is live. Consequently simply
calling TERM on a blocked v1674 child cannot reach foreign
`proc_finish_slot` while its RAW suffix is PACKED; it must first
restore/wake and unwind the borrowed stack. Changing that guard would
introduce a serious correctness regression, not test the terminal.

The new C89 user INIT and original-code PDP-6 child test only:

- PID2 executes a user-mode spin loop after native GETPID/BRK,
  instead of entering a private PIPE read continuation.
- Native PID1 must first observe the original `SYS_PROCINFO.words`
  reaching `06000` after PID2's actual BRK. Only then does it send
  `SYS_PROCCTL_EVENT_PID` with `SYS_EVENT_TSTP`, and the original
  scheduler changes the child to STOP. This closes an observed race:
  v1682's first exploratory guest sent TSTP too early, PID2 retained
  only its 02000-word initial APR, and the tenth RUN was admitted.
  That v1 guest is REJECTED, not treated as acceptance. A bounded
  native wait times out on missing APR growth rather than weakening
  the memory-pressure requirement.
- The other eight children use the unchanged deterministic PIPE-held
  read path. Fragmented real native RUN pressure evicts stopped PID2
  and the other inactive children into original RAW PACKED owners.
- At original physical checkpoint B, a source-derived monitor reads
  the full MM descriptor and all process/source ownership as in v1673,
  **plus PID2's saved original `CTX_PC` word from its real u-area**.
  The source-linked validator requires STOP state, PACKED mode,
  no private scheduler WAIT class and a saved USER-mode return PC.
- PID1 then sends a genuine `SYS_EVENT_TERM` to PID2 without waking
  any PIPE reader; the native foreign-fatal/finalizer path must accept
  it. All eight other children are released through their pipe, then
  PID1 checks the signaled child and all ordinary EXIT/WAIT statuses.
- The original full A/B/C physical-MM and native SYS_MEMINFO oracle
  must prove no orphan owner, pin or leak after the mixed lifecycle.

No production KCORE, MM, MRES or event guard code is changed. No
synthetic MM pin is introduced in this *control*; if it passes,
a separate physical test may attach an original MM pin to that
exactly validated PACKED owner at the correct timing. It may then
check original physical `FINALIZE+PREVM`, scheduled idle retries,
fail-closed owner and verified original MM-unpin recovery.

The fixture is compiled and linked using existing original v1673
source builders, with `V1673_GUEST_C`, `V1673_CHILD_ASM`,
`V1673_CTY_DRIVER`, and `V1673_MEASURE` pointing to these
versioned tests. Build all test sources from the same source
checkout; do not mix fixture image, original KCORE map or DXR hashes
across runs. B's USER-PC, MM/PROC/WAIT and mode evidence is mandatory.

Run:

    DAIMOS_REPO=<PURE-source-worktree> \
        V1682_VARIANT=general sh run-control-v1682.sh

GENERAL and STRICT require separate source-linked physical boots.
P1-E, true MM pin/unknown owner, fault-specific write-watch
high-water and all-branch mainline integration remain OPEN.
