# K05 v1901: actual PDP-6 user TERM on a genuinely quarantined dual owner

Date: 2026-11-23. **Original source-built 48K PDP-6 physical PASS**:
the ordinary user-mode `SYS_PROCCTL_EVENT_PID` / `SYS_EVENT_TERM`
request is REFUSED for a real previously faulted TRANSITION-held
child whose saved `CTX_PC` is an **executive** continuation. This
refusal is required to preserve the child's original private kernel
stack, not a missed opportunity to free its MM allocations.
K05-K09 remain OPEN; RAW PURE and mode3 remain OFF by default.

## What this establishes

The accepted v1900 full-system experiment physically established
that source-linked REAL KCORE `mm_free(PACKED)` refusal can leave
two same-slot MM owners after failed FULL. The corrected optional
v1900 terminal MRES can safely reclaim both only when a legitimate
FINALIZE+PREVM owner reaches that code path; the original foreign
event dispatcher rejects a slot in `TRANSITION` before that path.
The missing full-system terminal trigger therefore needs explicit
physical context proof. It is not safe to bypass that event guard
without checking the saved executive continuation.

`prepare-source-v1901.py` reproduces the accepted five-child
ROOT/secondary DTC3, BRK/PIPE and independently resident parent
from the original v1892 pressure fixture. Its only substantive
addition is ONE real parent `dsys_procctl(SYS_PROCCTL_EVENT_PID,
SYS_EVENT_ARG(3U,SYS_EVENT_TERM))` request and ASCII `TA`/`TR`
result markers. The original source remains C89-compatible.
The selected target is actual child slot3, not a synthetic PID.

The first experiment had a **test-controller synchronization
error**: the parent sent TERM during an earlier HB, before
the original MM fault, and emitted `HBTA`. That run is REJECTED;
it is not a terminal fault witness. The corrected version uses
`volatile kword_t v1901_term_gate` in the parent's USER APR.
The original guest's linked `init.map` locates this at logical
`005265` octal. The accepted physical parent APR is `130000`,
so the only SIMH deposit is **physical `135265`**, inside that
one test-only user variable. The controller must observe it
initially zero at the FIRST HB **after** original MM refusal,
then deposit `012345670123` octal. The caller's C code itself
reads the gate and executes the real `SYS_PROCCTL` once.
No MM descriptor, process flag, kernel instruction, event outcome,
or register result is deposited or otherwise fabricated.

## Original physical evidence

The final source-built guest has unchanged fixed KCORE and v1900
optional PURE binaries. Original KCORE SHA256:
`33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b`.
Original corrected PURE SHA256:
`09bcb71e4cbb172222f6389153c27293353fdaf6d3210eeef4630ed06de934f2`.
The one test-only user INIT DXR SHA256:
`e678526d30901f58308bf3d10bba0df0c8b0c648d75367fc32eaabca60f4ffd9`.
Selected original 48K PURE base is `032417` octal.

The full-system trace executes the original PACKED source
`mm_free` at `035310`, actual `MM_ERR_BUSY=-5` at `035311`,
retains both source and scratch PROCESS extents at original
MM count18, slot3 TRANSITION, VMbase0 and all other MM/ROOT
owners. Only after that is the parent user gate armed. Actual
user output `TR` verifies the *original* `SYS_PROCCTL` returns
failure while the child is quarantined.

Physical slot3 metadata at relocated process-table address
`045025=046133600401`, VM `045026=010000000000`.
Saved u-area is `046133`. Its original `CTX_PC` at `046153`
is **`340000016664`**, which has the saved USER-return bit
`010000` CLEAR in the left half. Thus the child has not
completed its private executive continuation. Original FDCTL
at `046157=000000004010` and FINALIZE word at
`046222=000000000000` remain unmodified by the refused TERM.
The source PACKED metadata at `024703=000014000003`
remains externally pinned (pin1); the complete provisional
PROCESS target at `024705=000001000003` remains pin0.

The live parent is slot1 at the two independently emitted
postfault user HBs and at TERM. The original real PCLK advances
`022015` -> `022115` octal across those HBs. The actual
terminal refusal does not clear TRANSITION, publish an APR,
delete either owner or mark FINALIZE. The test does NOT falsely
claim that a foreign user TERM can clean up a saved executive
stack by forcing FINALIZE.

Accepted original normalized physical trace SHA256:
`ce5460ee0b43593eeb158b60f11df7dd7336918e9ad0977d9afc7677ae8bc251`.
Private accepted evidence directory:
`$TMPDIR/daimos-k05-transition-term-v1901-physical-gated/`.

## Independent source-backed audit

`verify-physical-v1901.py` reuses the complete v1895/v1900
source-linked original physical owner/root/parent/PCLK oracle,
then verifies the exact gate deposit, actual `TR` event result,
physical child saved-CTX, FDCTL/FINALIZE, complete original MM
owner-table conservation and timing. `audit-physical-v1901.sh`
rechecks original SIMH log normalization and executes NINETEEN
unsafe controls: NINE separately corrupted actual v1901 gate,
event, user context and owner witnesses plus TEN original
v1895 physical owner, pin, process, PCLK and heartbeat mutants.
All must fail at precise independent oracles; all **PASS**.

## Repeat

In the daimos-testkit repo:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export DAIMOS_REPO=$HOME/git/DAIMOS
    export V1901_SOURCE_DIR=$TMPDIR/daimos-k05-transition-term-v1901-source-gated
    make test-pure-k05-transition-term-build-v1901

The source-build prints the new versioned `pure-brk-pressure-v1614.*`
physical boot directory. With the accepted recorded fixture:

    export V1901_BUILD=$TMPDIR/pure-brk-pressure-v1614.DjLn6k/build
    export V1901_PROBE=$TMPDIR/daimos-k05-v1900-physical-probe/probe.clean
    export V1901_PRIOR=$TMPDIR/daimos-k05-persistent-source-pin-v1895-real
    export V1901_V1900=$TMPDIR/daimos-k05-terminal-physical-v1900-real-v3
    export V1901_WORK=$TMPDIR/daimos-k05-transition-term-v1901-physical-gated
    make test-pure-k05-transition-term-physical-v1901
    make test-pure-k05-transition-term-audit-v1901

## Remaining K05 requirement

An original FULL failure with both owner extents but no safe
immediate restoration leaves `TRANSITION` held. The current
`ppure_retryable_v1612` requires exactly ONE slot-owned MM
descriptor; this retained two-owner state cannot be unlocked
even after an external pin later disappears. Event delivery
also cannot destroy the still-owned private executive stack.
The next production design must provide **bounded, exact owner
reconciliation and target rollback from a safe slot-0 context**
when physical pins permit, preserve the original saved private
continuation, and only then allow the usual owner-managed fatal
event/EXIT/finalizer. This is not solved by bypassing the
TRANSITION guard or by a simulator-forged FINALIZE marker.
