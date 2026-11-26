# K09 current KCC pressure and RAM budget v1951

Simulator cb6a255 (installed v1950), SHA256
60eb5ed95aab5da99d014c6c49eb0ef77635dc0b878e62b47da4d807f7e8a204.
No DAIMOS production code modification. All observations are
native PDP-6 execution and read-only monitor examinations.

## Accepted 48K mixed FULL lifecycle

Fresh KCC GENERAL and STRICT kernel images prepared in
$TMPDIR/k09-kcc48-pressure-v1949.Yzi0LN/{general,strict}/build
(the earlier simulator runs on these images were withdrawn).
Replayed on installed v1950 in
$TMPDIR/k09-kcc48-pressure-v1951.T6qP70/{general,strict}/physical.
Guest fixture is the GCC-built v1941 five-child test, one plain
and four compressed children. Same fixed KCORE and PURE images
across both profiles. All five admitted, sixth RUN denied,
B/A MM18 unchanged. Installed FULL callback 042415,
opcode 200000000004, slot0; slot3 PACKED111000..120000 and
PROCESS120000..130000 both pin1. Five exact EXIT/WAITs and
child/parent data checks, Z MM8 high slot2, parent VM and u-area
intact, no child owner, no pipe owner or reservation, one idle
stack pin, normal HALT PC0 and simulator exit0.

Both profiles: managed 28195, B/A allocated 24083, free 4112,
largest gap 1935, packed17920. FULL allocated24460/free3735,
pinned7936 including idle stack. Z allocated4958/free23237,
largest gap23237, packed0. B/A tick15214 GENERAL,14365 STRICT;
FULL24208/23022; Z32121/31484. Gross RAW savings2560 words;
not enough to offset installed PURE3879.

Physical clean trace SHA256:
GENERAL 2acc870bbb0d54c42f4371838c31fd32fe5fa0f754055d1a32ab1efebb66e553
STRICT 058ee423f05fb96b31814f0e03930524233bf3bdb9423e0e3f6f7db115d2632c
Original v1941 verifier and additional v1951 conservation
verifier PASS on both. Four altered conservation snapshots
per profile rejected (not live hardware faults).

## Accepted 64K matched physical OFF/RAW budget

OFF fresh build $TMPDIR/k09-off-v1951.3uuDVw/build, RAW
$TMPDIR/k09-kcc64-v1948.6N5W0A/general. Original INIT, no
AUXSTORE, same fixed KCORE, actual INIT checkpoint.
$TMPDIR/k09-budget64-v1951.d5Qr6j/{off,raw}/console.clean
and budget.json. The initial host verifier double-counted
the MM table; corrected independent replay of the captured
complete snapshots passes. The actual boot traces are unchanged.
Installed code/data 16966/20845, MM table80 both, managed
boot kernel dynamic614 both, total allocated4974 both,
free43468/39589. Fixed plus table17046/20925 exceeds16K
by662/4541 before scratch. Four altered trace controls rejected.
Linked KINIT+bootstrap stack reservations OFF27911,
GENERAL32056, STRICT30172 words; not physical high-water.

## Remaining active pressure tests (NOT accepted)

64K nine-child mixed fixture freshly built for GENERAL/STRICT
under $TMPDIR/k09-kcc64-pressure-v1951.7hfblX. Not executed.
The historical v1674 nine-owner 48K workload has five enlarged
and four ordinary APRs. Live current KCC baseline is 24247 free,
not the previous roughly 27K. Even its fully packed final
owner requirement 24776 exceeds that baseline by529 words.
Initial graphical runs stopped; headless isolated ports fixed
the runner, both reached A and launched children; deliberately
stopped before end-to-end test because geometry cannot fit.
Recalibrated test uses two enlarged and seven ordinary APRs,
unchanged nine owners, exact original 128-word RAW skip, same
pipe/WAIT workload and refusal requirement. Its GENERAL build
and live A checkpoint reached; stopped before lifecycle
completion. No claim that the new geometry produces the
required fragmentation until a complete physical run passes.
Evidence $TMPDIR/k09-nine-v1951.3amWfv,
k09-nine-headless-v1951.3crQlD, k09-nine-recal-v1951.3AY5ai.

## Reproduce

    export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
    export DAIMOS_REPO=$HOME/git/DAIMOS
    # Fresh build (WORK must not yet exist):
    sh tests/validation/pure-k09-pressure-v1951/prepare-v1951.sh WORK 48 general
    V1951_BUILD=WORK/build make test-pure-k09-pressure-v1951
    # 64K variant, not yet executed:
    sh tests/validation/pure-k09-pressure-v1951/prepare-v1951.sh WORK64 64 general
    V1951_CORE=64 V1951_BUILD=WORK64/build make test-pure-k09-pressure-v1951
    # Recalibrated 48K nine plain children:
    V1951_VARIANT=general make test-pure-k09-nine-v1951
    # Matched standard-INIT lowmem 64K images with PURE off/on:
    V1951_OFF_BUILD=OFF V1951_RAW_BUILD=RAW make test-pure-k09-budget-v1951

The new combined targets have not themselves been run end-to-end;
the 48K replay, original and extra verifier, and budget verifier
components have been executed as described above. K09 OPEN.
