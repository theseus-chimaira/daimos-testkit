# D6CODEC grouped/block native PDP-6 comparison, v1420-v1424

Date: 2026-11-10. All source variants are unlinked experiments.
Production DAIMOS still uses D6LZ36.

From the daimos-testkit root, set:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
    export DAIMOS_REPO=/path/to/DAIMOS-experiment-worktree
    export DAIMOS_BUILD_DXR_DIR=$HOME/git/DAIMOS/build/system/boot/pdp6

Then run:

    sh tests/validation/d6codec-compare-v1422/run-v1422.sh
    sh tests/validation/d6codec-compare-v1422/run-errors-v1422.sh
    sh tests/validation/d6codec-compare-v1422/run-register-v1424.sh
    python3 -B tests/validation/d6codec-compare-v1422/run-full-dxr-v1422.py \
        "$DAIMOS_BUILD_DXR_DIR" "$DAIMOS_REPO" "$TMPDIR/d6codec-full-v1422"
    python3 -B tests/validation/d6codec-compare-v1422/measure-register-v1424.py \
        "$TMPDIR/d6codec-register-v1424" "$DAIMOS_REPO"
    python3 -B tests/validation/d6codec-compare-v1422/blt-stats-v1422.py \
        "$TMPDIR/d6codec-compare-v1422"
    python3 -B tests/validation/d6codec-compare-v1422/hardware-model-v1424.py \
        "$TMPDIR/d6codec-compare-v1422"

The first runner extracts v1367 sources from the historical DAIMOS
branch for an unchanged control, renaming only its exported test
labels. No production object or Makefile is modified. The host
generators independently encode and roundtrip the 29 real DXRs and
create versioned PDP-6 assembly fixtures.

The results above have been checked: 24 initial success paths,
22 malformed grouped/block tests, eight register-resident success
paths, ten register-resident malformed-input tests, and 15 complete
native DXR decode-and-compare runs. The full-image test checks
KCORE, D6FS, MonitorFS, SWAP and tape per decoder.

Expected standalone native text/frame budget:

| Engine | Engine | Adapter | Frame | Native CRT canary |
|---|---:|---:|---:|---:|
| Grouped v1367 | 225 | 92 | 67 | 71 |
| Grouped v1420 | 272 | 92 | 67 | 71 |
| Block v1421 | 181 | 92 | 48 | 52 |
| Register block v1424 | 75 | 89 | 40 | 43 |

The repeatable simulator step-limit measurements for the mixed
2,477-word DXR fixture are 94,115 / 57,169 / 3,999 / 2,490
respectively. These are *SIMH instruction counts*, not PDP-6
clock cycles. BLT is one simulator instruction even for a
multiword transfer; the separate hardware model counts BLT words,
but uses only illustrative per-instruction timing assumptions.

Full discussion and the remaining production boot/RAM gates are
in pdp10-doc/KERNEL/D6CODEC-STREAMING-OPTIMIZATION-V1424.MD.
