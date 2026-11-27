# v1987 actual directory terminal and restored EXEC

Validation-only, no production kernel changes. Use accepted v1985
source-built strict swapless TSFS GCC 64K build. Repack only user
fixtures and three TSFS root tapes, preserve original KCORE/MRES/KINIT
bytes, private writable tape copies, no deposits beyond normal boot,
no artificial interrupts, no injected faults or kernel hooks.

    export DAIMOS_REPO=$HOME/git/DAIMOS
    export PDP10_PREFIX=$HOME/cross
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1987_BASE_BUILD=<accepted v1985 build>
    make test-pure-directory-lifecycle-build-v1987
    export V1987_BUILD=<reported build>
    export V1987_WORK=<new unique work directory>
    make test-pure-directory-lifecycle-physical-v1987
    make test-pure-directory-lifecycle-audit-v1987

Guest source builds unmarked INIT, independently linked marked PURE
DXR2 compressed COMP and distinct unmarked PURE POST. INIT spawns
unmarked PIPE slot2, marked PIPE EXEC slot3, then marked spinner
children. Each spinner writes a readiness token to a separate PIPE,
closes that descriptor, spins in user mode. Parent sleeps before
authorized TSTP, checks STOP and exact typed STOPPED status. Physical
pressure checks actual saved user PCs and no private wait class.
Parent TERM/WAITs every stopped child without CONT, then wakes PIPE
children. Slot3 checks all sparse data, EXECs POST; only POST may
emit X and exit056 (old plain child exits057). Parent checks exact
PIDs, statuses and own sparse data. No user-accessible compression
mode is assumed: observer verifies actual MM/mode3 owners.

Read-only original monitor extended by optional lifecycle observer;
legacy RAW and v1986 invocation unchanged. Actual relocated terminal
entry guards against early mode3 restore; compare original source,
saved PC, backing, FILE table and exact TRANSITION. After typed WAIT
marker require no process/u-area owners or stale mode. At L all stopped
children retired; EXEC child still owns original bitmap. Actual
FULL and atomic finish, marked resident EXEC entry, distinct new
record/unmarked image at proc_exec_enter with same slot/u-area,
no reservation or escrow, actual POST marker and final MM/HALT.
Offline verifier also checks original kernel hashes, guest DXR2
headers, root tape conservation and exact marker stream.

Accepted evidence relative TMPDIR:
pure-directory-lifecycle-build-v1987.Qwey5T/build,
pure-directory-lifecycle-physical-v1987.JkKVum.
TSFS members3 files55 extents316. Actual pressure12 children:
slot2 RAW3584, slots3..6 bitmap251 each, slots7..13 resident4096.
Foreign TERM slots4/5/6 at octal063000/064200/065400, each251,
no restore, three exact owner retirements. All10 STOPPED and
TERM/WAIT checks. Slot3 restore061600/251 ->160000/4096,
actual EXEC at000147, new unmarked POST2048 at proc_exec_enter024311,
same slot/u-area, changed record, no reservation; X, all12 EXIT
WAITs, final MM/HALT, all three root tapes unchanged. Independent
verified-final-v1987.txt and trace-controls-v1987.log PASS, eleven
corrupted trace controls rejected.

Native current-source regressions v1934 EXEC, v1982 terminal,
v1985 placement pass; logs pure-directory-lifecycle-regression-v1987.1rHs4R.
Historical v1681 extraction was stale (missing real v1937 stack guard);
repaired test-only extraction and added an overlapping reservation
refusal and executed bypass mutant. Final native v1681 PASS and
five mutants rejected, evidence daimos-pure-terminal-finalizer-v1681.3zLbCj.

Scope: healthy actual 64K PDP-6 foreign mode3 TERM and post-restore
marked-to-unmarked EXEC accepted. No claim of physical PREVM pin
fault/retry, dirty recovery, 48K or KA10 physical acceptance, RT latency,
or real DSH workload. No production enable.
