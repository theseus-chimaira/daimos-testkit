# Direct MEMFS PURE mutation admission, v1938

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-memfs-mutation-v1938

The source-linked native PDP-6 gate executes the actual MEMFS runtime,
data allocator and PURE backing/mount scanners with the existing
controlled MM and backstore fixture. Eight owner configurations cover
transient loader, staged RUN, resident and nonresident PURE, at public
mount IDs 2 and 18. Provider-local and canonical vnode writes,
truncate, resolved-child unlink and PREPARE_UNMOUNT refuse while
owned. Metadata, allocation and contents remain unchanged; unrelated
writes and mutation after owner release succeed. Five unsafe controls
remove write/truncate/unlink/unmount protection or canonicalization
and fail executed native assertions. Unsafe unmount is detected by
changed storage state even if a later fixture MM free refuses.

The historical MEMFS allocator, fatal backstore/XIP and FIFO tests pass.
Their isolated fixtures have no published VFS mount; added scanner
stubs refuse unexpected calls. The FIFO fixture's stale data-release
and XIP linkage was also corrected. Other historical runners were not
all rerun. GCC emits an existing include-search-order warning.

This test controls MM and physical backing completion. It is not an
integrated scheduler or physical-media test. No new permanent data.
