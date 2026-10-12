# D6FS creation write-order model — 2026-10-12 v1

This host-side Python model enumerates the crash boundaries in the current
D6FS child-FCB / parent-dirent publication sequence. The source-grounded
sequence is: child FCB, optional symlink data/extent, optional parent growth,
six-word dirent, and parent FCB size/mtime. The last boundary is conditional:
when an existing directory slot is reused, its parent size may not change.

The model confirms orphan windows after child FCB creation and before the
entry is visible. An entry written to a slot beyond published parent EOF can
also remain invisible until parent FCB publication. **This is a conservative
abstract model, not a kernel executable or a durability proof.** It assumes
whole-block writes occur in the listed order and that each completed write
can survive a crash; it does not simulate torn sectors, write reorder,
metadata block sharing, or the multiple writes made by resize/bitmap logic.

The important consequence is that merely adding a commit flag after the
existing in-place metadata writes does not eliminate orphan crash windows:
recovery must detect and reconcile pre-commit intents, or metadata must be
staged copy-on-write with an atomic root selection rule. In-place directory
updates demand separate torn-write analysis. A future test should cut SIMH
power at each backing-write boundary and check each cloned image with
`d6fsck` before and after recovery.

Run: `python3 tests/validation/daimos-d6fs-create-write-order-model-20261012-v1.py`
