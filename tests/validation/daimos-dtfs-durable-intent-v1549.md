# v1549: candidate durable DTFS write-intent record protocol

Date: 2026-11-13. **Design/model evidence only; no live kernel guard.**

Current native DTFS has a valid DTVOL1 RBN0 identity and on-mount
volatile WRITE_UNCERTAIN, but it does not store a durable intent
record. Reproducing an old, physically damaged, previously discarded
stamped tape after reboot is therefore still an OPEN P0-B defect.

The v1549 model introduces a six-word candidate DTVOL2/CLEAN versus
DTVOL2/WRITE_INTENT record in the existing reserved RBN0. It never
automatically promotes the old, historically ambiguous DTVOL1 and
legacy tapes. The actual Type-551 error profile previously observed
in v1529 can change only a prefix of the physical 128-word block.
Consequently the model enforces physical readback of a *complete*
dirty intent record **before** starting any data/directory write.
An incomplete marker update cannot authorize a write. A partly
completed data write retains the dirty record, which a fresh
mount must reject even if the old identity and directory match.

Two independent offline suites PASS:

- `daimos-dtfs-durable-intent-v1549.py`: 16 protocol invariants,
  128 prefix-partial marker writes and 128 prefix-partial clean
  commits, valid seal checks, dirty cold/reinsert refusal,
  replacement ID inequality, and strict padding/old-media denial.
- `daimos-dtfs-durable-media-v1549.py`: operates on real new
  host `mkdtfs` DECtape images (two 18-bit lanes per 36-bit word).
  It round-trips an *experimental* candidate DTVOL2 RBN0 on an
  isolated copy, writes one of two requested data words at actual
  RBN0145 in physical image bytes, retains the dirty RBN0 seal,
  checks independent replacement ID, and reopens the original
  media file as a simulated cold boot. Five assertions PASS.

Execute:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
python3 tests/validation/daimos-dtfs-durable-intent-v1549.py
python3 tests/validation/daimos-dtfs-durable-media-v1549.py \
    "$PDP10_PREFIX/bin/mkdtfs"
```

**These are not full-guest/native PDP-6 validations.** The image
conversion is a test-only offline transformation; production
`mkdtfs`, `dtfs_probe`, `dtfs_mount_unit`, `dtfs_dtc_write`, and
VFS unmount have NOT been patched. In particular, current KCORE
would reject the candidate new RBN0 as malformed and would still
admit an old stamped tape. Do not put an experimental DTVOL2
image into a production DTFS unit, and do not claim P0-B closed.

The remaining implementation requires one coordinated formatter,
probe and provider update, provider-serialized raw RBN0 mark and
readback with separate 128-word scratch storage, a final owner-safe
clean unmount seal, compatibility/migration policy, native mutations,
and actual v1529 partial Type-551 physical full-guest cold-reboot
tests. See `DAIMOS/design/kcore-dtfs-durable-intent-v1549.md`.
