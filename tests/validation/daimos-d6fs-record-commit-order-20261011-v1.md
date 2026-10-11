# D6FS record append write-order audit — 2026-10-11 v1

This is a **source-order diagnostic**, not a crash-atomicity acceptance test.
It asserts the current unsafe ordering so future changes cannot accidentally
be presented as atomic without a separate recovery validation.

Observed source sequence:

1. `d6fs_provider_write_words` reads the FCB and resolves append EOF while
   the provider is serialized.
2. For growth it calls `d6fs_provider_resize_fcb` **before writing payload**.
3. `d6fs_resize_publish` changes the FCB size/extent metadata and invokes
   `d6fs_reader_put_fcb`, which writes that FCB through to backing storage.
4. Only then `d6fs_reader_write_words` copies payload; its transfer path
   commits each affected 128-word data block independently.
5. The caller updates file modification time and writes the FCB again.

Failure windows include: allocation-map changes before FCB publication;
FCB size becoming visible before the new payload; failure after writing
one but not all payload blocks; and the final FCB timestamp publication.
The rollback in `d6fs_provider_resize_fcb` handles normal detected failures
but is not a power-loss journal. The CLEAN/DIRTY A/B superblock mechanism
marks filesystem session state, not individual file-record commits.

A correct implementation needs a formally specified crash-recoverable point:
write new record contents and any mapping to unreachable shadow storage,
validate and flush them, then publish an independently recoverable commit
selector/metadata entry; old state remains readable until publication.
A single 36-bit commit marker is **not** assumed atomic across power loss
without a documented backing device guarantee. Reclaim abandoned blocks
only after recovery can identify committed ownership. Test injected failure
at each write boundary and reboot before declaring atomicity.

Current design is **not implemented**. The test script prints `KNOWN
NONATOMIC` as an audit pass; it must not be interpreted as crash-safe append.
