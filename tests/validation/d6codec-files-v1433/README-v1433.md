# Native file decoder choice: D6LZ36-BLT vs block v1424

Date: 2026-11-10. This experiment compares actual initialized
machine-code words from built DAIMOS DXRs, not synthetic
zero-filled process RAM. It changes no production file format.

## Reproduce

Use a DAIMOS checkout with the v1428 D6LZ36-BLT shared
decoder and the staged v1424 block decoder and adapter.
Set environment variables to match the local build:

    export TMPDIR=$HOME/tmp
    export PDP10_PREFIX=$HOME/cross
    export DAIMOS_REPO=/path/to/DAIMOS-v1429
    export BOOT_DIR=$HOME/git/DAIMOS/build/system/boot/pdp6
    mkdir -p "$TMPDIR/d6lz36-dsh-live-v1427"
    cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic -shared -fPIC \
      "$DAIMOS_REPO/tools/host/d6lz-codec.c" \
      -o "$TMPDIR/d6lz36-dsh-live-v1427/libd6lz36-v1427.so"
    python3 -B tests/validation/d6codec-files-v1433/compare-v1433.py \
      --boot "$BOOT_DIR" --daimos "$DAIMOS_REPO" \
      --d6lz-library "$TMPDIR/d6lz36-dsh-live-v1427/libd6lz36-v1427.so" \
      --prefix "$PDP10_PREFIX" \
      --output "$TMPDIR/d6codec-files-v1433"

The runner validates host-compressed streams, assembles the
actual fixed and block native decoders, executes them on PDP-6
and determines their retired-instruction counts using repeated
bounded simulator STEP runs. Small CRT and decoder-adapter
setup is included; output verification loops are excluded.

## Native results

| Compiled machine code | Raw | D6LZ36 payload | Block payload | D6LZ36 steps | Block steps |
|---|---:|---:|---:|---:|---:|
| Concatenated first 128 words of 29 DXRs | 2,477 | 2,348 | 2,320 | 23,603 | 2,490 |
| DSH first 2,048 words | 2,048 | 1,850 | 1,868 | 19,213 | 5,039 |
| KCORE first 2,048 words | 2,048 | 1,993 | 1,983 | 20,181 | 2,961 |

All six native runs pass. Results are archived in
results-v1433.tsv. These are **SIMH instruction counts, not
hardware microseconds or cycle-accurate speedup**: a single
BLT may transfer many output words.

The full 29-image compressed corpus favors block by only
120 words over D6LZ36: 37,190 versus 37,310 for 48,487
original words. The block decoder+VFS frontend costs
164 standalone TEXT words instead of 96 for D6LZ36-BLT,
but its temporary VFS frame is 40 versus 72 words.

The long-term preference for files is block v1424, subject
to a hard Stage-1 size/placement gate, full linked KCORE
acceptance and bounded shared EXEC/PURE decoding. Stage-1
currently uses a 39-word fixed D6LZ36 decoder, not a
75-word block core. Never ship both file decoders as a
permanent workaround.
