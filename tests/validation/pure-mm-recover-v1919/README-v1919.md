# Native deferred DROP/PREFIX recovery, v1919

Run against the DAIMOS source tree with the installed KCC/DAS/p10run:

    DAIMOS_REPO=$HOME/git/DAIMOS sh run-v1919.sh

KEEP_TEST=1 retains the native build and logs in a unique TMPDIR directory.
The real service, DROP, PREFIX, FULL and MM rebase/claim/release/commit
assembly run on the PDP-6 simulator. Pin/unpin, allocation, PI, backing
loader and idle-clock arming are fixtures. The armer intentionally
replaces u-area 067 like the permanent KCORE routine.

Three DROP paths exercise a committed PACKED owner, a rejected rebase
with original resident owner, and committed MM rebase before mode
publication. Four PREFIX paths exercise held PACKED full span, held
unpublished PROCESS, foreign retag/replacement, and excess pins.
They verify a refused new pin, refused release, lost successful
pin/release/unpin replies, slot-zero-only retry, noncurrent reclaim
arming, exact suffix contents, no allocation/free, saved u-area,
backing, scheduler cursor, escrow, mode, PI balance and READY_ONCE
only after a fresh normal restore. Existing pins are not consumed by
idle retry. The test explicitly retires injected pins before recovery;
it does not claim automatic recovery of an unowned persistent pin.
Six invalid marker/shape combinations are refused without mutation.

Five unsafe service-source copies must fail target assertions:

- missing DROP arming: 0101
- accepting an existing pin: 0403
- trusting new-pin return instead of exact descriptor: 0412
- ignoring transaction kind: 01004
- discovering a replacement RAW base: 0607

The baseline passes all cases; compiler, linker or timeout failures
are not accepted mutation results. The v1918, v1612, v1902 and v1906
native gates also pass in this stage. Physical PI6 and terminal
uncertainty acceptance are separate gates.
