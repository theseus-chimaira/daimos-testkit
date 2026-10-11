# D6FS backing-write injector v1 — 2026-10-12

A testkit-only generator `tools/fault/d6fs-fault-write-v1.py` creates an
isolated assembler variant of DAIMOS `fs_backing.s`. It inserts a
logical-block comparison into `fs_backing_write`; writes to the selected
logical block return the normal negative error result before calling the
backing adapter. Reads are unchanged, and no production DAIMOS source,
resident state, or disk layout is modified.

The host contract assembles this variant with DAS, verifies the logical-block
comparison, and ensures the read dispatch is unchanged. **This is a generator
validation, not a live SIMH rollback or power-loss acceptance test.**

Remaining work: build a SIMH image that substitutes the generated backing
object at the correct filesystem module link boundary, determine a safe
logical target for staged payload and metadata writes, execute an injected
failure, check old file size and data, run d6fsck, and test ambiguous final
FCB publication. In particular, the injector is a persistent block filter,
not a one-shot ordinal fault; do not infer a commit outcome from it alone.
The implementation must not be enabled in normal production images.
