# v1972 native KA10 DCS0

Production 50f775b6. Enable existing Type630 MRES/MINIT
and simulator DCS at0300/0304, eight-line default,
TCP DCS0_PORT=1101, CTY0 and logical TTY1 LOGIN entries.
GE remains excluded. Current SIMH KA10 deliberately
retains WAITS line bias2, DCSB DATAO to selected send
line, unlike PDP6. Translate at assembly device boundary.
Receive PI2 claims only armed, stopped scanner; RM10
shares PI2, so idle DCS must not manufacture input.
65 resident words (63 initialized, 2 original BSS),
3 more than PDP6 DCS, zero fixed KCORE growth.
Matched PDP6 KCORE/KINIT/maps/stream/Stage1/DCS identical.
No SIMH changes. Hardware equivalence not claimed.

Build stock KA10 ROOT=tape and ROOT=disk; run:
    python3 run-v1972.py TAPE_BUILD DISK_BUILD PDP10_PREFIX WORK FIRST_PORT
Actual CTY and independent TCP DCS0 login; distinct ECHO
output on both, DCS PWD, EXIT, invalid login, relogin
and independent CTY after DCS respawn. Root/backstore,
zero used sectors, active DRM0, second DMA pair zero.
Blank login attempt refreshes prompt if early TCP
carrier assignment misses it. Unique TCP ports, private
media. D6FS without/with RM10 both PASS. TSFS both reach
INIT with DCS OK; full shell acceptance still open.

Fresh D6FS+RM10 actual six-child swap with DCS installed:
    V1972_DCS_IDLE=1 sh ../k17-rm10-v1970/run-swap-v1970.sh BUILD WORK
Checks actual PI2 dispatch patch, first DCS instruction,
two BSS words zero at A/B/C. MM9/20/8 free43747/1203/43761,
bitmap0/64/0, reads2/2/66 writes0/64/64 errors0.
Exact WAIT/canaries and stable MM ownership; media
descriptor/reserved area unchanged, backing written.
No reader or TCP connection in swap fixture; idle DCS
mailbox/event stay zero across real RM10 interrupts.
Concurrent active DCS RX and RM10 DMA not yet qualified.
Evidence $TMPDIR/k17-dcs-v1972.3KPvNN/interactive-final,
swap, ka-{disk,tape}, pdp6-matched.
DCS DXR SHA256
566ae2380a6580db60384022455bfaba08db88c714d7a8d99b3429f009fea410.
