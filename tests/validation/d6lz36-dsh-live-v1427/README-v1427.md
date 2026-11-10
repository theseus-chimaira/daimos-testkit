# D6LZ36 production decoder baseline on captured DSH RAM (v1427)

The v1427 test uses the read-only real PDP-6 process snapshots
captured by v1426. It compiles the actual DAIMOS host D6LZ36
compressor, asserts exact decode roundtrips and runs the unchanged
40-word native PDP-6 decoder, along with grouped and block controls.

| DSH state | Raw | D6LZ36 | Grouped | Block | RAM RLE |
|---|---:|---:|---:|---:|---:|
| Idle | 3200 | 277 | 246 | 280 | 263 |
| Six variables | 3200 | 508 | 439 | 532 | 537 |
| Function | 5248 | 614 | 524 | 656 | 677 |

| DSH state | D6LZ36 steps | Grouped steps | Block steps |
|---|---:|---:|---:|
| Idle | 17928 | 9055 | 1684 |
| Six variables | 19377 | 18008 | 3376 |
| Function | 30637 | 23104 | 5114 |

Reproduction requires DAIMOS_REPO pointing to the unoptimized
v1426 decoder and the v1426 live captures in TMPDIR.
Run run-v1427.sh. Versioned TSV files store the measured counts
and source hashes; actual guest memory remains in TMPDIR.
SIMH steps are instructions, not hardware cycles.
