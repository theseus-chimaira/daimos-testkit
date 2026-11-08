# v1364: Stage-1 physical-memory admission before payload writes

These tests cover a staged grouped D6CODEC Stage-1 change. Production
Stage-1 sources, boot media and the D6LZ36 codec remain unchanged.

The assembled PDP-6 helper
`system/stand/pdp6/common/stage1-geometry-v1364.inc` accepts:

- AC1: uncompressed KINIT words U (must be nonzero)
- AC2: compressed words C (zero means raw image)
- AC3: configured physical core limit M, in words
- AC4: reserved KINIT stack words S

It returns AC0=0 only if `030000 + U + S <= M` and
`030000 + U + C <= M`, or -1 on failure. All other ACs are preserved;
only the ordinary PUSHJ/POPJ return word uses the Stage-1 stack.
The header parser separately checks entry offset and compression mode.
Input counts are read from 18-bit header halves; the helper performs
the arithmetic in 36-bit ACs so none of the sums silently truncate.

Native PDP-6 tests cover a valid 32K image, the exact 32K
output/stack endpoint, one-word overflow, the exact 32K staged
source endpoint, one-word staged overflow, zero-length input,
the full 256K physical endpoint and register preservation.

The `generate-v1364.py` script extends the already validated test-only
v1363 direct-linked Stage-1 alternatives. It takes **both** the
configured physical core size and stack reserve in octal. The helper
call executes after the complete boot header is validated, and before
the first compressed or raw payload write in all five loader paths.
For PTR, the first tape segment is additionally refused if it exceeds
the declared compressed stream length, before reading any of its words.

The runner assembles all five alternatives in both standard profiles
(32K `0100000` and 256K `01000000`, default reserve `0400`).
Ten native PDP-6 fixtures execute the actual generated pre-write
guard instructions, checking exact acceptance and refusal, including
an oversized first PTR tape segment. Two further checks validate
an override profile (64K `0200000`, stack reserve `02000`).
No installed decoder, boot format or KCORE runtime is changed.

The inspector compares generated source text size and BSS against
the same v1363 alternatives. Added footprint is transient Stage-1
instructions only, with **no BSS increase**:

| Loader | +text, 32K | +text, 256K | BSS increase |
|---|---:|---:|---:|
| DSK | 20 | 21 | 0 |
| DRM | 20 | 21 | 0 |
| DTC | 22 | 23 | 0 |
| MTC | 22 | 23 | 0 |
| PTR | 24 | 25 | 0 |

Run:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-stage1-geometry-v1364/run-v1364.sh
```

Remaining gates: actual device boot from five loaders, full grouped
KINIT media generation, corrupted/truncated media, end-to-end rollback,
and the atomic runtime/host producer conversion. These tests do not
establish any of those production properties.
