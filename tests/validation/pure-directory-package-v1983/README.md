# v1983 source-built directory PURE MRES (experimental)

Accepted package gate:

    make test-pure-directory-package-v1983 DAIMOS_REPO=/path/to/DAIMOS

Builds actual KCORE and the complete relocated MRES with GCC and KCC;
checks absence of new directory symbols in fixed KCORE, absence of the
old interleaved codec, exact regeneration across directory -> RAW ->
directory switches in the same build directory, and refusal of old
format or nonstrict combinations. The observed installed package
resident lengths are GCC RAW3258/directory5359 and KCC RAW3885/
directory6401 words (zero BSS); KCORE -8 in the directory profile.

Physical lifecycle diagnostic (NOT an acceptance gate yet):

    export DAIMOS_REPO=/path/to/DAIMOS
    sh tests/validation/pure-directory-package-v1983/prepare-guest-v1983.sh
    # Use the printed V1983_BUILD path and a fresh TMPDIR work directory.
    python3 tests/validation/pure-directory-package-v1983/replay-v1983.py \
        "$V1983_BUILD" "$WORK" "$PDP10_PREFIX" --core 64 --timeout 1150

The preparation builds the actual strict swapless 64K TSFS image,
independently links an unmarked INIT and a marked child from the same
source, compresses the latter's DXR2 payload with the real block tool,
and validates the rebuilt three root members. Capacity determines the
admitted child count (4..12); all admitted children must check every
word of their sparse data array and return the exact status to WAIT.
The diagnostic observer uses private copies of media and relocated
link addresses, no deposits or simulated fault injection. It requires
real mode3 MM owners at pressure, actual restore/finish entry, exact
source and target pins, and final child owner retirement. The runtime
oracle is preliminary until an actual complete trace validates it.
Do not treat PURE LOADED alone or a partial trace as K15 acceptance.
