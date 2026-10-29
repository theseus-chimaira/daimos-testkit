# v695 — D6FS backing dispatch binding audit

This audit follows the fixed-MRES direct-binding project, not general KCORE
minimization. The D6FS MRES `fs_backing.s` contains four physical backend
entry words (DSK/DRM read/write). Each is both a `JRST` tail-call target for
non-root physical requests and a `PUSHJ` destination for boot-root requests
which additionally update logical D6SET accounting.

KINIT already patches D6FS module-local jump slots through the module export
table. The DSK backend depends on root selection; the DRM backend is patched
when installed. The generic `fs_backing_read/write` functions separately
resolve per-descriptor *packed 18-bit* callback addresses. They therefore
serve runtime-selected mounts rather than a single fixed MRES target.

Potential next experiment: patch both the ordinary tail-call site and the
root-accounting call site directly for each of the four physical services.
That could remove up to four trampoline words and one jump on root requests,
but the existing tail-call instruction itself must remain and the new patch
sites must be KINIT-addressable. The actual net word count, error defaults,
and interrupt-safe interface need linked and native A/B verification.

No change to production was made here because deleting the `JRST` slots
without fully replacing both incoming paths would break D6FS secondary
mounts or root accounting.
