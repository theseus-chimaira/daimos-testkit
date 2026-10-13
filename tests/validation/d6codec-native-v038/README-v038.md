# v038 — native compressed-stream parity using real DXR payloads

Three 128-word samples are extracted from the actual DAIMOS-built DXR
executables listed in the v006 corpus. The C99-free Python generator
`generate-fixtures-v038.py` handles little-endian, 8-byte-stored 36-bit
words and skips the recognized DXR headers. Fixed sample words are saved
in `.s` test fixtures so future reruns do not require access to DAIMOS's
build directory. The generator is provenance tooling, not part of the
native test.

| DXR | Payload offset (words) | Stream parity on PDP-6 |
|---|---:|---|
| configctl.dxr | 0 | PASS |
| darc.dxr | 64 | PASS |
| d6lz.dxr | 128 | PASS |

Two native encoders are linked with separate symbols: v031 baseline
(126 code words) and v036 cursor (127). Each compresses the same 128-word
DXR payload and checks that compressed lengths and *all* compressed 36-bit
words agree. These parity checks passed on PDP-6.

Independent encoder-only step-limit runs (no decode/compare) show:

| DXR sample | v031 baseline at 50,000 steps | v036 cursor at 50,000 steps |
|---|---|---|
| configctl | FAIL / incomplete | PASS / completed |
| darc | FAIL / incomplete | PASS / completed |
| d6lz | FAIL / incomplete | PASS / completed |

Both need over 30,000 steps on these samples. These are simulator bounds,
not exact retired instruction or PDP-6 cycle counts. No full-executable
native compression, host v020 ratio comparison, malformed-input fuzz or
production KCORE validation is claimed. The cursor optimization is now
supported by real-DXR binary parity and improved speed bounds.

Only versioned testkit files changed; concurrent DAIMOS/KCORE untouched.
