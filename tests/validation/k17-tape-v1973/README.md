# v1973 native KA10 TSFS locality and swap acceptance

The previous full tape workloads are slow because stock file data
follows the in-place boot tail. Repack a private three-member set
using a test-only copy of mktsfs with initial data member 1.
Independently validate both sets with the stock tsfscheck and
compare exact Stage1/bootstrap tail, file table, extent shapes,
checksums and every stored/compressed extent word. Full mode
also verifies the reference tape images equal the original
stock tape images. All production code and timing unchanged.

    python3 repack-v1973.py BUILD DAIMOS_REPO WORK pressure
    V1973_SETTLE=1 V1971_ROOT=tape V1972_DCS_IDLE=1 sh \
        ../k17-rm10-v1970/run-swap-v1970.sh WORK RESULT

Pressure mode retains INIT, MOUNTALL (exact v1955 six-child
fixture DXRs), configuration and directories (13 file records,
11 extents). Full mode keeps all 43 file records/256 extents.

The first pressure run completed six WAITs and canaries but
the original physical verifier rejected checkpoint B: PID1
and the sixth child had not yet entered their blocked state
and the sixth child had not completed BRK. Do not accept
or relax the original oracle. The optional settle callback
reads actual process descriptors and requires every user
blocked, every child 8192 words, no outstanding storage or
drum operation before the existing strict snapshot. Diagnostic
monitor output stays in raw log and separate settle-A/B/C
logs, not in the canonical snapshot transcript. All three
gates reached on first check in the final run.

Current v1972 KCORE and DCS DXRs identical to the accepted
build. Final native 64K TSFS+RM10 pressure PASS: MM9/20/8,
free42661/117/42675, bitmap0/64/0, reads2/2/66, writes0/64/64,
errors0. Six exact WAITs/canaries and pipe cleanup, stable
MM owners restored, both unused DF10 words zero, DCS idle
mailbox/event zero at A/B/C. All four tapes unchanged,
drum reserved region unchanged. Original v1959 disk and
v1972 drum reports still reproduce exactly.

Evidence $TMPDIR/k17-tape-v1973.fel8Sn/swap-final.
Console SHA256 4e6d22e3cdab14478fb4d3780e7f5536ca323df70441706830dc3695a82747f1.
Report SHA256 bd2c3c32622a7fe9cbefd8c223ff02b3dd0befa79dcd4abfda5dc77eac944f91.

Interactive test (separate full layout):
    python3 repack-v1973.py STOCK_BUILD DAIMOS_REPO FULL full
    python3 shell-v1973.py FULL PDP10_PREFIX WORK FIRST_PORT

The no-backing case runs CTY and DCS shell sessions serially;
the RM10 case keeps both shells alive. The final snapshot
allows allocated backing only when exactly accounted for by
a live DISK owner and the physical bitmap, not simply because
a guest printed a prompt. No claim of active RX/DMA overlap.

Final native shell replay PASS on both full relocated stock
images, preserving all four tapes in each profile. No-RM10:
CTY ROOT/ECHO, EXIT to respawned LOGIN, DCS ROOT/ECHO/PWD;
all three live APR owners exact and backing0. RM10:
both ROOT shells live, distinct ECHO and PWD, CTY still
usable after DCS command. Exact live APR owners and bitmap,
PID1 slot1 DISK run first0,count32, not a leak. Backing
capacity512, active DRM0, second pair0. Earlier full
RM10 replay also verified DCS logout, invalid login,
respawn and independent CTY, then rejected the incorrect
zero-used assumption. Initial no-drum concurrent DSH
attempt deliberately stopped without acceptance. Final
no-drum test is serial; do not claim simultaneous DSH
without backing. Generic old log label "simultaneous ...
logout/respawn" on custom callbacks was misleading;
corrected to distinguish the selected shell test.
Evidence $TMPDIR/k17-tape-v1973.fel8Sn/shell-final.
