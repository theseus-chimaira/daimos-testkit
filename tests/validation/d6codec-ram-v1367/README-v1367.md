# v1367 staged grouped decoder RAM minimization

Run: `DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-ram-v1367/run-v1367.sh`

The runner exercises the versioned grouped decoder and its VFS adapter
on native PDP-6, using the independent v1359 host KCORE/MRES goldens.
It checks the v1366 VFS ABI/invalid-input matrix, a 15-descriptor
zero-run stress test, the touched kernel stack canary, and 15 full
128-word native prefix reconstructions (five DXR categories times
refill windows of 1, 7 and 64 words). The build is staged only.

All native test runs PASS, including the 15 current DXR/window
combinations. The emitted object measurements are:

| Component | v1366 | v1367 |
|---|---:|---:|
| Engine text | 237 | 225 |
| Adapter text | 96 | 92 |
| Combined text | 333 | 317 |
| Decoder state | 26 | 25 |
| Temporary VFS frame | 68 | 67 |
| Native stack canary (octal) | 0110 | 0107 |

The test suite enforces v1367's 225/92 text ceiling, the exact
25-word state and 67-word frame layout, a stack-canary result of
`0107` octal (71 decimal), and zero object data/BSS. The result
saves 16 permanent code words versus v1366 but still adds 220
resident code words versus the 97-word production D6LZ36 path.

This suite does NOT prove full production KCORE linking, nested
VFS provider stack safety, or a complete grouped-format OS boot.
