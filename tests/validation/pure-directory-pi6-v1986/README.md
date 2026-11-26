# v1986 actual mode3 scheduler and PI6 gate

Native:

    make test-pure-directory-selector-v1986 DAIMOS_REPO=/path/to/DAIMOS
    PURE_TEST_COMPILER_V1984=gcc make test-pure-directory-selector-v1986 DAIMOS_REPO=/path/to/DAIMOS

Source-link the actual original scheduler selector (clock and explicit
reschedule entry), complete directory service, native real MM and
bounded restore from the v1981 fixture. Native fixture uses original
base bitmap placement; moved source is exercised by the physical test.
Actual independent resident peer and its u-area; source provider and
fault replies controlled, not physical interrupts. Each CPU/compiler
44 selections and 16 service calls; normal/lost success, clean refusal
and retry, dirty false-success quarantine, stale READY on nonresident,
STOP and TRANSITION, and exactly-once priority override. Six executed
selector mutants reject. v1981 default runner unchanged in behavior.

Physical:

    python3 replay-v1986.py BUILD WORK "$PDP10_PREFIX" --core 64 --timeout 1150
    python3 verify-v1986.py BUILD WORK "$PDP10_PREFIX"
    python3 test-trace-v1986.py BUILD WORK "$PDP10_PREFIX"

Use the accepted v1985 64K source-built image. Read-only observer extends
the original replay without changing the image, no deposits or simulated
interrupts. Resolve actual linked loader, real clock PI6, atomic finish,
idle-loop service call return and first dispatch, with competing stops
for premature dispatch/service return. Compare exact pinned MM pair,
source bytes, u-area/record identity and transaction escrow at loader
and PI6; saved executive PC classified using actual installed PURE,
TAPE, DTFS/TSFS bindings. Verify actual clock advance, READY_ONCE from
committed mode0, exact target owner and consumed one-shot cursor at
first dispatch. The same child must emit its original checked data
marker. Require all original WAITs, final MM and HALT. Independent
verifier requires these additional actual witnesses and rejects the
historical v1985 trace alone. No claim of actual EXEC or nonresident
terminal acceptance, nor hardware fault injection.

Native evidence relative to TMPDIR: pure-bitmap-service-v1981.yR19lT
(KCC), pure-bitmap-service-v1981.SzbumO (GCC), both CPUs and all six
mutants PASS. First fixture had a duplicate mismatched return type
for the already-declared selector; removed the fixture declaration.
Historical v1650/v1677/v1808 and default v1981 all PASS, logs in
pure-directory-pi6-regression-v1986.KVv6Xc. Actual monitor rearm probe
k08-simh-break-rearm-v1946.Nqo9HS confirms rearming current PC repeats
without executing it. First physical run pure-directory-pi6-v1986.yw48Uh
independently passes --scoped through READY publication: slot3, original
061400/239 and target160000/4096, actual PI6 PC032131 in TAPE,
tick15814 -> finish/READY16929, all bitmap words unchanged. Seven
scoped corrupted traces rejected. It stopped before dispatch because
the observer rearmed the just-stopped READY return PC; not a kernel
failure. Corrected observer guards service entry, not current return
PC, when proceeding to first dispatch. --scoped never proves dispatch
or final cleanup.

Corrected full physical replay: pure-directory-pi6-v1986.aHbEE0.
Independent verified-final-v1986.txt and trace-controls-v1986.log PASS.
Slot3, original 061400/239, destination 160000/4096, actual saved
TAPE PC032131; PI6 tick17905, finish/READY/dispatch/guest tick19058.
First dispatch selected slot3, consumed READY_ONCE, and the same
child produced its checked data marker. All 12 WAITs, exact final
MM, normal HALT. All ten corrupted-trace controls rejected. KCC
repeat Makefile run pure-bitmap-service-v1981.pWDyrI PASS.
Healthy physical PI6/READY_ONCE gate closed; physical fault injection,
actual EXEC, and nonresident terminal destruction remain separate gates.
