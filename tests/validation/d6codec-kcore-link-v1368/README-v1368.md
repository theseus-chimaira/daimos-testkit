# v1368: grouped codec complete KCORE/MRES link and fold analysis

Run against a current, fully built DAIMOS KCORE:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-kcore-link-v1368/run-v1368.sh
```

The runner reads the real `KCORE_FIXED_OBJS` and `KCORE_FOLD_OBJS`
directly from the DAIMOS Makefile. It re-links production KCORE with
the existing fold plan and demands **byte-identical** KCORE DXR,
RIM and initialized stream images. It never writes into DAIMOS's
normal build outputs or alters a production code or filesystem format.

It then assembles v1367's grouped native decoder and ABI-compatible
adapter under test-only filenames (the latter supplies the existing
`d6lz36_decode_vfs` and `d6lz36_decode_buffer` external symbol names).
The remainder of KCORE retains its original compiled object order.
The grouped runs compare the unchanged production fold plan against
a regenerated plan including the grouped adapter and engine.

Three low-core layouts are compared:

- `legacy`: the old 40-word decoder is still present, but no new call
  site uses it. This is a **measurement-only dual image**, never a
  proposed runtime fallback.
- `reserved`: replaces those 40 words with non-executable reservation,
  preserving the exact original early EXEC code placement, with only
  the grouped decoder active.
- `none`: removes the old decoder slot completely, shifting the early
  EXEC routines 40 words down. This is the smallest candidate, but
  requires distinct boot relocation and low-core ownership approval.

Full linked sizes with regenerated fold plan (36-bit words):

| KCORE | Text | BSS | Text delta | Exclusive end (octal) |
|---|---:|---:|---:|---|
| Production | 9601 | 269 | 0 | `023276` |
| Grouped, no low-core reservation | 9817 | 269 | +216 | `023626` |
| Grouped, reserved low-core slot | 9857 | 269 | +256 | `023676` |
| Grouped with old decoder retained | 9857 | 269 | +256 | `023676` |

Using the production fold plan instead yields +220 or +260 words.
The regenerated plan has 31 folds with 75 donor words, rather than
29 folds with 71 donor words. Only two new two-word folds involve
the grouped decoder; **four** words are saved from new folding.

The runner also re-links five actual MRES packages against both
grouped KCORE maps: SWAP, DTFS/TSFS, D6FS, MonitorFS and tape.
Their original-map links are byte-identical with the already built
normal MRES objects. Their grouped-map links succeed with precisely
the same initialized/BSS/resident sizes as the originals:

| Package | Resident words |
|---|---:|
| SWAP | 1757 |
| DTFS/TSFS | 1834 |
| D6FS | 2175 |
| MonitorFS | 1592 |
| Tape | 405 |

Both grouped KCORE variants also convert to proper SIMH RIM and
initialized-word stream files with their *own* `__kcore_low_init_end`
boundaries. This does not establish that the KINIT boot installer can
be safely cut over or that grouped runtime media work. Full cold
boot, real nested VFS provider stack and end-to-end compressed
EXEC/PURE/TSFS decode remain OPEN.

Most importantly, **all of these grouped outputs are test artifacts**
under `$TMPDIR`. Production remains D6LZ36 without code, map,
boot-image or MRES package changes.
