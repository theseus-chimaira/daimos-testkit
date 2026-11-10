# v1366: native grouped D6CODEC VFS and buffer runtime adapter

Status: isolated assembler-only PDP-6 test; NOT installed in KCORE.

Run with a current linked DAIMOS KCORE/MRES DXR directory:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-vfs-v1366/run-v1366.sh
```

The test exercises two versioned staged assembler components:

- `system/kernel/core/d6codec_stream_v1366.s`: group decoder v1361
  extended with DS_REMAIN=-1 for trusted immutable VFS input of unknown
  exact length. Nonnegative compressed counts still require complete,
  exact consumption; malformed negative values are refused.
- `system/kernel/core/d6codec_vfs_v1366.s`: normal C ABI-compatible
  AC1..AC4 entry and complete-buffer entry (same caller convention
  as `d6lz36_decode_vfs` and `d6lz36_decode_buffer`). It preserves
  AC10..AC16 and uses only per-call stack storage, no static state.

The VFS fake provider is deliberately a leaf routine, with bounded
32-word read windows and controllable short seven-word replies. The
native PDP-6 test uses the current KCORE DXR's independently host-
encoded 128-word golden stream and compares all 128 decoded words.
It covers exact VFS mode, short refills, immutable trusted backing
with a surplus compressed tail, direct exact buffer mode, early EOF,
malformed first control, bounded trailing input, shortened direct
source, invalid direct overlap, zero-length direct input, malformed
negative or 19-bit input counts, decoded output into the stack frame,
input source alias of the frame, and AC10..AC16 preservation.

The native canary using `crt_stack_v051.s` reports `0110` octal
(72 decimal) stack words touched. This includes the test CRT's
main call and the decoder's nested calls, but NOT real VFS/provider
cold-read depth or kernel syscall nesting. The internal VFS frame is
68 decimal / `0104` octal words: 7 saved ACs + 3 locals + 26
continuation state + 32 input-window words. The old D6LZ36 VFS
frame is 72 decimal words (6 ACs + 2 locals + 64 input window).

Native assembly object budget (36-bit words):

| Component | Old D6LZ36 | Grouped staged v1366 |
|---|---:|---:|
| Token engine | 40 | 237 |
| VFS/buffer adapter | 57 | 96 |
| Combined text | 97 | 333 |
| Static data/BSS | 0 | 0 |

This is a **+236 word permanent text increase** if substituted for
the old code, before any whole-KCORE link/folding effects. The test
runner rejects unreviewed text growth beyond these provisional maxima.
Saving four stack words does NOT offset the 236-word KCORE growth.

Remaining cutover gates: real VFS/provider nesting and stack-watermark
tests, a KCORE link/size check, partial output cleanup on read
failures, all compressed callers and full atomic host/media format
conversion. No mixed runtime formats or production fallback are
accepted. This stage establishes interface feasibility, not RAM
budget acceptance.
