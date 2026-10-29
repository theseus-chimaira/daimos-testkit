# v689 — MRES dispatch inventory (source audit)

This audit is limited to module-linking and dispatch architecture. It does
not inspect unrelated KCORE buffers, VFS metadata, or caches.

KINIT already calls `storage_patch_jump()` for many fixed KCORE entry
instructions and `storage_patch_module_jump()` for MRES-local call sites.
The script counts **call occurrences**, not distinct resident sites, and
does not infer RAM savings from the count.

Filesystem VFS dispatch still selects one of four provider entry slots
(MEMFS/DTFS/D6FS/TSFS), whose targets are patched at KINIT. The provider
gateway also serializes sleeping physical-provider operations; removing it
requires preserving that lock and the caller's saved registers. Inside each
filesystem, a packed 18-bit vector lookup chooses the operation. The two
shared C-ABI dispatchers handle normal and context-register calling forms.

The runtime module mover exists in `module_runtime_pdp6.s`, but the boot
Makefile does not link it and `module_runtime.c` calls its integration
deferred. Consequently the installed fixed bindings are presently stable,
but dynamic relocation/removal is **not** a safety property proved by any
direct-dispatch experiment. Future removability needs binding retargeting,
quiescence and sleep-safe lifecycle management.

Architectural decision: retain provider selection where runtime vnodes can
name different filesystems; retain the 18-bit packed operation vectors
unless a fully functional alternative reduces **total** resident KCORE +
MRES words; treat PI, optional-device and fixed-service jump slots as
separate classes rather than indiscriminately replacing them.

No DAIMOS production change is made by this inventory.
