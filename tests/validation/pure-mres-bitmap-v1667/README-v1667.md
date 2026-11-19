# v1667: opt-in bitmap PURE MRES integration, no production mode3

Parent DAIMOS v1666:
`0d30d2c4eac0fd3466f0bdeeb6c69f35931c334e`.

The default kernel and ordinary PURE MRES remain unchanged. To
compile the staged bitmap helpers into PURE MRES only, set BOTH:

    DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=1

The Makefile rejects the opt-in for ROOT=disk/drum, missing PURE
or unsupported flag values. ROOT=tape and ROOT=auto are accepted
because either can choose TSFS at runtime. KINIT still chooses
the memory backend by the selected root and validated BACKSTORE;
positive BACKSTORE installs DISK and never installs the bitmap
PURE candidate. The unselected package can remain transient in
a general ROOT=auto boot image. No new permanent process word or
backend selector is added.

Staged PURE MRES directly exports the small C `proc_pure_term_v1667`
at terminal export index 2. Mode2 goes to the original v1609
PDP-6 RAW MM owner release; mode3 calls v1661 bounded compressed
owner release. Both require their own exact mode and complete
physical owner proof, with fallible free followed by atomic mode
publication. DISK and mode0 are rejected by the PURE dispatcher.

The existing v1612 PURE slot-0 service checks the 2-bit map only
with the opt-in flag. Mode2 retains its existing prefix/FULL
restore; mode3 calls the v1664 bounded FULL APR reconstruction
and original v1660 stream preflight. On failure, v1667 reuses
the same v1664 authoritative source scan to unlock TRANSITION
ONLY if exactly one unpinned encoded source remains, executable
backing is still valid and no APR/other process MM owner exists.
Uncertain MM state stays TRANSITION-held. A successful restore
requires one complete 4,096-word APR image and resident mode0.

**No mode3 is yet reachable from a real running process.** The
fixed `vm_space_destroy` still refuses mode3, and the normal
reclaimer only creates RAW mode2. The v1663 bitmap compressor
is not linked into a production reclaim path. Do not use this
stage in production as a compression system; enabling it adds
MRES code without recovering any real process RAM. RUN/EXIT/WAIT
and PI6 acceptance must precede production mode3 admission.

## Native tests

    DAIMOS_REPO=/path/to/DAIMOS PDP10_PREFIX=$HOME/cross \
      TMPDIR=$HOME/tmp \
      sh tests/validation/pure-mres-bitmap-v1667/run-v1667.sh

This sources the original v1609 process/VM fixture, actual KCORE
`proc_swap_detach` C, original v1609 PURE assembler and v1661
terminal C, plus the real v1667 dispatcher. Native PDP-6 executes
21 mode2/mode3 positive/refusal cases: compressed success, RAW
success, same-ID MODULE owner, invalid modes, saved backing,
TRANSITION, pins, duplicate MM ownership, malformed length,
still-mapped APR and MM free refusal. An independently compiled
unsafe mutation dispatches mode3 into the RAW-only leaf and is
rejected by the native oracle.

    DAIMOS_REPO=/path/to/DAIMOS PDP10_PREFIX=$HOME/cross \
      TMPDIR=$HOME/tmp \
      sh tests/validation/pure-mres-bitmap-v1667/run-service-v1667.sh

This invokes the genuine v1664 original-MM source-linked runner
then reuses its exact source-extracted PDP-6 allocator, MM owner
pin/unpin/free, v1662/v1663 compressor and v1660 decoder, with
the original 4,096-word FULL restore test fixture. The new v1612
service is compiled with the v1667 flag; 16 service cases cover
successful sparse/all-zero mode3 slot-0 RUN restoration, exact
APR contents, failed physical allocation and loader after writes,
bad literals, false pin/uncertain rollback, backing/map mutation,
incorrect current slot, state and request. Uncertain state must
remain TRANSITION held and never enter READY_ONCE.
The service runner also executes an independently compiled unsafe
mutation that bypasses the failed-restore MM ownership proof.
The native oracle detects premature TRANSITION unlock after an
uncertain target-pin failure; compiler/guest failures do not
count as valid mutant rejection.

For a strict source/build-policy guard and linked symbol ownership:

    V1667_FULL_STAGE=/path/to/v1667-kcc-auto \
      V1667_FULL_BASE=/path/to/v1666-kcc-auto \
      V1667_GCC_STAGE=/path/to/v1667-gcc-tape \
      V1667_GCC_BASE=/path/to/v1666-gcc-tape \
      DAIMOS_REPO=/path/to/DAIMOS \
      sh tests/validation/pure-mres-bitmap-v1667/run-policy-v1667.sh

It checks correct TSFS/PURE opt-in prerequisites, rejects invalid
ROOT and PURE combinations, proves identical fixed KCORE end and
ensures the terminal/restore/decoder/MM finish/codec symbols only
appear in PURE MRES. `run-physical-v1667.sh` builds and boots a
64K physical PDP-6 TSFS root with this opt-in and no AUXST1; it
checks PURE LOADED, INIT V1 and exact source-linked symbol ownership
but does not claim live compressed RUN/EXIT/WAIT operations.
The source-built 64K TSFS/no-AUXST1 opt-in physical guest boots
to `MEM 64 K`, `DTC OK`, `PURE LOADED`, `INIT V1`. An initial
script assertion used the wrong version of the fixed KCORE
terminal symbol and stopped before SIMH; correcting it to the
unchanged v1666 entry allowed the exact built image to PASS.

## RAM cost

The v1666 baseline installed KCC FULL PURE MRES is 2,307 words.
The v1667 opt-in package is 3,992 words, adding **1,685** words.
The GCC lowmem PURE MRES grows from 1,863 to 3,186 words,
adding **1,323** words. Fixed KCORE does not grow in either build.
The transient KINIT image end additionally grows by **1,778**
KCC FULL words (octal 140230->143612) or **1,396** GCC lowmem
words (octal 113732->116516); these are temporary code-image
staging costs, not a measurement of physical RAM high-water.
These are costs, not savings: no live process is yet compressed.
One successfully compressed 3,456-word RAW example in the v1663
native fixture encodes to 161 words (3,295 words fewer), but
that measurement is not a full-guest admission, nor a peak-RAM
result. True net memory gain must be demonstrated with real
process lifecycles before enabling this code permanently.
