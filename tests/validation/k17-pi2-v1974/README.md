# v1974 native shared PI2: active DCS receive and RM10

Source-linked production KA10 DCS and RM10 leaves, real
RC10/DF10 and DCS TCP input, native PI2. The disposable
DCS copy redirects its tail to the RM10 handler exactly
as production MINIT patches the relocated tail. No guest
mailbox, device status, interrupt or DMA-state deposits.
The test's own event/wakeup stubs record which real
completion occurred; not a full scheduler test.

Mode0: wait until actual DCS scanner has stopped with a
pending byte, then issue native RM10 DATAO before enabling
PI. DCS wake observes an active request and RC10 BUSY.
Mode1: same, but wait for actual RC10 DONE before enabling
PI. Both pending; DCS wake precedes drum completion, BUSY
clear. Mode2: arm DCS, complete native RM10 with no TCP
byte, inspect completed request and zero RX count, then
send the byte. All three require exactly two wakes, one
RX, ASCII Z returned by production getchar, exact 128
DMA words, guards intact, completed descriptor, disk read
counter, exact DF10 completion word, and unchanged second
pair and original media.

    python3 run-v1974.py DAIMOS_REPO PDP10_PREFIX WORK PORT MODE

MODE=0,1,2. Use distinct unused local TCP ports. Initial
harness corrections: GO must advance past initial HALT,
wait for actual TCP line assignment before sending input,
and leave global PI off until intended overlap. Final
three chained runs exit0. No production code change or
simulator changes; zero RAM growth.

Evidence $TMPDIR/k17-pi2-v1974.HMnc5A/chain-{0,1,2}.
Active DCS RX and DMA at hardware/handler level accepted.
Full native scheduler under an active DCS reader and
backing pressure remains separate.
