# v1988 physical PREVM retry and complete native mode3 finalizer

Validation only, unchanged accepted v1987 image (v1985 KCORE/MRES/KINIT).
No new kernel code or persistent process words.

Native:

    make test-pure-directory-prevm-native-v1988 DAIMOS_REPO=$HOME/git/DAIMOS
    PURE_TEST_COMPILER_V1984=gcc make test-pure-directory-prevm-native-v1988 DAIMOS_REPO=$HOME/git/DAIMOS

The optional v1985 test-runner branch links the complete original
proc_finish_slot, idle finalizer, backoff, parent eligibility, actual
u-area MM release and executive-stack reservation guard. Actual
relocated mode3 DROP, original common detach, staged VM destroy and
real MM pin/unpin/free. Outer session/TTY/notification/adoption
callbacks remain controlled fixture services (not actual scheduler
or clock interrupts). Original parent has its own exact MM owners.
21 counted finalizer/reaper calls per CPU/compiler: actual one/two
pins, refused/false free reply, lost successful free reply,
repeated PREVM and backoff, exact original bitmap bytes and span,
one final ZOMB publication, no second HUP, source and u-area
retirement. Actual saved executive PC, private wait, live FILE,
and overlapping stack reservation reject before teardown.
Eight executed finalizer mutants reject per compiler, with native
assertions: ignore VM refusal, no PREVM, lose span tag, no backoff,
no stack guard, no user PC, no wait guard, no FILE guard.

KCC/GCC PDP6/KA10 PASS, evidence relative TMPDIR:
pure-bitmap-placement-v1985.4k1mr9 and .NJA2fK.
Initial test-only prototype and duplicate-symbol issues resolved;
short alias at original backoff entry avoids KCC identifier
truncation. Existing GCC include-order warning, no new toolchain
defect. Original v1681, v1982 and v1985 suites PASS, logs
pure-directory-prevm-regression-v1988.QZ1jYp.

Physical:

    export V1987_BASE_BUILD=<accepted v1985 build>
    export V1987_BUILD=<accepted v1987 fixture build>
    export V1988_WORK=<new unique work directory>
    make test-pure-directory-prevm-physical-v1988
    make test-pure-directory-prevm-audit-v1988

Reuse original v1987 real user TERM/WAIT and restored EXEC fixture.
At first stopped compressed terminal entry, introduce one explicit
external test pin (modify only the exact MM descriptor pin field).
No synthetic timer, return code, process flags, source bytes,
backing or forced dispatch. Resolve private retry word from actual
linked MOVE and TLNN instructions, not a hardcoded address.
Observe actual slot-zero timer-gated backoff and terminal retry
twice. Do not rearm the currently stopped terminal PC; guard the
different original finalizer/service entries and FULL. Original
complete table and exact pinned owner, stable u-area, saved user
PC, backing/credential, terminal status, BRK span and word067
PREVM tag, all original bitmap words preserved. No early guest
WAIT or dispatch. Release exactly the introduced pin at the second
idle retry entry. Original kernel performs retirement and WAIT.
No new physical claim for permanently missing/foreign owners.

Accepted physical evidence:
pure-directory-lifecycle-build-v1987.Qwey5T/build,
pure-directory-prevm-physical-v1988.IuWoyT (physical.clean,
audit-v1988.log). Twelve admitted, three stopped compressed TERM
owners, slot4 fault source063000/251. Actual retry ticks8042/8074,
delay16->32->64. All ten stopped TERM WAITs, restored slot3 EXEC
to distinct POST, all12 EXIT WAITs, exact final MM and HALT PC0,
unchanged root tapes. Independent verifier reuses v1987 full
lifecycle oracle after validating only the delimited fault segment;
all11 corrupted trace controls reject. Old healthy trace rejected
by new gate. Native test checks cleared retry state after success;
physical trace checks exact retirement but does not sample the
private retry word after successful scan.

Two preliminary physical replays stopped before fault injection:
private clock word not exported (resolved from actual instruction),
then redundant same-PC breakpoint guard identified (removed in
favor of different finalizer/service entry guards).
Final full replay exit0, no simulator remaining.

Scope: physical terminal known-pin refusal, real PREVM timer retry
and successful retirement accepted at 64K PDP6. No claim for general
K16 uncertainty, source loss, physical FULL fault recovery, latency,
48K, real DSH or default activation.
