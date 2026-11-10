# Trusted-memory zero-bitmap v1451: native tests and module analysis

This directory contains the **final tested 30-word PDP-6 bitmap
encoder/decoder**, before MM or KINIT integration. It is intended
only for internal immutable-while-packed process RAM on a
swapless TSFS-root DAIMOS system. It is not a file decoder and
does not accept data from untrusted sources.

## Source and ABI

bitmap-v1451.s uses 30 TEXT words, no static DATA/BSS, no
extra stack frame and no heap. AC10..AC15 are preserved:

- Encode: AC1=original source, AC2=positive decoded count,
  AC3=packed destination. AC3 returns first unused output word.
- Decode: AC1=packed source, AC3=destination, AC4=positive
  original decoded count. Restores data, no return status.

The MM caller owns disjoint source and destination buffers,
computes the exact bitmap extent as ceil(count/36) +
nonzero count, supplies sufficient capacity and retains
that representation until atomic process restoration. The
native codec intentionally repeats **none** of the trusted
MM input/capacity checks.

Each 36-word (or short final) group begins with one 36-bit
presence mask followed by all nonzero literal words.

## Run the validations

The real DSH snapshots from v1426 must be available under
$TMPDIR/d6codec-shell-live-v1426. Set TMPDIR to $HOME/tmp
when it is not already set. From the daimos-testkit root:

    sh tests/validation/d6codec-compressor-v1451/run-v1451.sh

This runs eight exact native PDP-6 decode/encode roundtrips,
including three full real DSH process-memory captures and five
boundary patterns, and one ABI fixture checking preservation
of AC10..AC15. It also assembles and measures the actual
30-word image. No production DAIMOS sources are modified.

For reproducible native instruction counts:

    python3 -B tests/validation/d6codec-compressor-v1451/speed-v1451.py \
      --snapshot-dir "$TMPDIR/d6codec-shell-live-v1426" \
      --work "$TMPDIR/d6codec-bitmap-v1451/speed" \
      --prefix "$HOME/cross"

For the normal DLINK two-export MRES package and p10fold
cross-domain analysis against block v1441:

    export DAIMOS_REPO=/path/to/DAIMOS-v1441-worktree
    sh tests/validation/d6codec-compressor-v1451/package-fold-v1451.sh

The measured resident bitmap image is 30 words; the temporary
MRES package is 36 words. With p10fold minimum run=2, neither
module orientation offers a safe resident reduction. Minimum
run=1 proposes sharing a single POPJ at the cost of a
cross-module dependency; no fold was installed.

## Native v1451 speed results

| DSH state | Original | Packed | Encoder steps | Decoder steps |
|---|---:|---:|---:|---:|
| Idle | 3,200 | 314 | 20,335 | 23,219 |
| Six variables | 3,200 | 524 | 20,965 | 23,639 |
| Function | 5,248 | 677 | 33,826 | 38,395 |

Counts include minimal CRT/test calls but omit the separate
full-data verification loops. They are PDP-6 SIMH instruction
counts, not measured hardware time. The estimates at the
nominal 250,000 instructions/s are in speed-v1451.tsv.
Core-only time excludes MM preflight, scheduler, allocation,
ownership, APR restoration and all TSFS operations.

The final code is not yet a boot-installed MRES or a live MM
transaction. Do not enable compressed-process scheduling
until those separate 32K/48K memory-pressure tests pass.
