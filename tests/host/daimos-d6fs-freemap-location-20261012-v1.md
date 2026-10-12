# D6FS allocation-map fault targeting (2026-10-12 v1)

The testkit-only host script `daimos-d6fs-freemap-location-20261012-v1.sh`
uses an isolated copy of the current DAIMOS `d6fsck.c` source to print the
validated selected superblock's free-map start. It compiles the diagnostic
copy using the host C99 compiler and runs normal read-only filesystem
validation. No DAIMOS source or on-disk structure is modified.

Observed on a cloned PDP-6 D6FS disk: check-only fsck reported CLEAN,
179196 blocks, 360 FCBs, and decimal `D6FS_FREEMAP_START=487`.
This value is **image-specific**; never hardcode it for other disks.

Next: pass the discovered logical block to the test-only backing-write
injector (`FAULT_LOGICAL`), run a disposable file operation whose allocation
would change this bitmap, and verify syscall error/old EOF, boot behavior,
and `d6fsck`. This locator alone does not demonstrate allocation-map error
handling or rollback. Because the block filter is persistent, distinguish
failed cleanup writes from the original allocation failure in the test.
