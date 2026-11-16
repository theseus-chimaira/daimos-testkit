# P1-E v1624: typed process-admission and BRK pressure diagnostic

The original v1614 child/PIPE/WAIT test reported the same `!c` for
both a failed `RUN` and a child which did not reach `PROC_SLEEP` in
the bounded parent `PROCINFO` polling loop.  This testkit-only
experiment disambiguates them as `!r` and `!s`.  The guest's kernel,
PI6, MM, PRIVATE PURE, executable ABI and child data checks remain
unchanged.  Only the number of children, parent BRK target, and the
two parent failure markers differ from the original source.

Use `prepare-v1624.py` to obtain an exact source-checked variant;
`check-source-v1624.sh` verifies five- and six-child generation at
`016000` and `017000` octal targets.  To run the full physical image:

    DAIMOS_REPO=/path/to/DAIMOS PURE_CHILDREN_V1624=6 \
        PURE_BRK_TARGET_V1624=016000 \
        sh tests/diagnostics/pure-pressure-cause-v1624/run-v1624.sh

The runner uses the normal original PDP-6 KCORE build and real
Type-551 physical root, with no AUXSTORE.  It preserves source,
compiled user image, linked maps, boot media and physical trace
in a unique `$TMPDIR/pure-brk-pressure-v1614.*` directory.  The
v1614 acceptance runner exits nonzero on a diagnostic refusal;
this is expected and must never be misreported as feature PASS.

After an actual complete HALT, run `audit-v1624.py` against the
preserved `user/init-v1614.c` and `console.clean`.  A five-child
`017000` test checks the exact observed non-returning BRK negative
case; a six-child test requires typed `!r` or `!s` before BRK.
Neither classification establishes working RAW reclaim or a
successful PIPE/WAIT/EXIT test.  Inspect source-linked MM and
APR geometry separately before changing production code.

## Original physical 48K results

The source-built five-child `017000` guest reaches
`aaaaa[B063060/042502]<010000+017000>`, then prints all five
child `w` markers and HALTs without a successful parent BRK
return or `Z`.  The original physical negative-control auditor
passes, and a falsified process-memory count is rejected.

The independent six-child `016000` guest reaches `aaaaa!rwwwww`
and HALTs, without executing parent BRK.  The split diagnostic
therefore proves the sixth `RUN` returned an invalid PID; it did
not time out while waiting for `PROC_SLEEP`.  An altered `!c`
physical trace is rejected by the source-sensitive negative
auditor.  The reason for the kernel's RUN refusal (for example,
MM allocation versus later executable startup) is NOT inferred
from the PID alone.  A source-mapped RUN failure-stage trap is
required before changing allocation or admission behavior.

An independently replayed five-child `017000` case with the old
v1615 `021324` fatal-close breakpoint timed out without reaching
that breakpoint.  It is inconclusive for the exact BRK failure
stage and must not be cited as proof of `MM_ERR_NOMEM` or a fatal
close regression.  The post-return and net-RAM gates remain open.

Do not mark P1-E closed without peak/net physical RAM, immutable
backing lifetime and full child/parent statuses.  The PURE service
remains opt-in, and all tests belong in daimos-testkit.
