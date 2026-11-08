# v1370: coherent grouped D6CODEC PDP-6 cold boot, LOGIN and RUN

This test boots an isolated **actual DAIMOS grouped-format kernel**
through INIT, LOGIN, DSH and a grouped ECHO program. The current
production D6LZ36 system is never modified or installed over.

Run from the root of `daimos-testkit` with the current staged DAIMOS
checkout, host toolchain and SIMH installed under `PDP10_PREFIX`:

```
DAIMOS_REPO=/path/to/DAIMOS \
    sh tests/validation/d6codec-fullboot-v1370/run-v1370.sh
```

All temporary results, per-phase logs and emulated media are under
`$TMPDIR/d6codec-fullboot-v1370`. The runner rebuilds the v1368
linked KCORE control and both grouped low-core alternatives, then
uses the **reserved-slot** grouped v1367 KCORE (original fixed
40-word low-core decoder replaced by non-executable reservation).
The reserved slot retains the early EXEC layout and costs +256
linked kernel text words relative to production, with unchanged
KCORE BSS. This is a correctness experiment, not a RAM optimization.

`build_grouped_image_v1370.py` evaluates the real Makefile's
`MRES_PACKAGE_OBJS` list and replays each of the **27 active native
MRES dlink commands**, replacing only the output paths and grouped
KCORE map. Every production-map control re-link must be byte-for-
byte identical to the existing MRES object. Each grouped-map MRES
must retain the original initialized/BSS/resident object dimensions.
The complete original KINIT must also link byte-identically before
the grouped KINIT is assembled. The new KINIT contains the actual
grouped KCORE words installed with the unmodified `mkimage.sh`.
It links with entry `054124` octal and load slot `030037..053240`.

The test independently encodes the full KINIT image as grouped
Stage-1 data (32926 decoded words, 29235 compressed), generates
the existing guarded v1364 direct-linked PDP-6 Stage-1, loads it
through the Type-760 paper-tape Stage-0 reader, and reads its KINIT
image from actual simulated Type-136 DECtape.

The host KCC PDP-6 compiler builds the original system userland.
The grouped executable producer converts normal DXRs into correctly
framed grouped DXR2 files with intact entry, text/BSS and relocation
metadata. The smoke root has 15 D6FS nodes: plain INIT and MOUNTALL,
grouped LOGIN, DSH and ECHO, and original INITTAB/FSTAB/PASSWD/SYSTEM
configuration. It is a **reduced test root**, not the full DAIMOS
distribution. Four DSK270 member images are generated with the real
`mkdsk`, `mkd6fs`, `logstore` and `d6fsck` tools.

Each SIMH boot receives a separate copy of the pristine CLEAN root
disk set. This is mandatory: normal boot may write a newer DIRTY
superblock, and reusing that disk for another independent comparison
can correctly fail with DAIMOS `?RT`. No filesystem error is hidden.

The negative control boots the original production D6LZ36 KCORE
and KINIT through the same grouped Stage-1 protocol using its own
pristine copy of the grouped root. It must reach INIT and report
`INIT: RUN FAILED` for grouped LOGIN, never a successful LOGIN.

The positive test boots the new grouped KCORE and 27 grouped-map
MRES packages with a fresh pristine grouped root. The runner uses
the existing `pty-run-v1` helper to enter ROOT interactively, wait
for the DSH `# ` prompt, execute `ECHO V1370GROUPED`, and require
the *standalone program output* `V1370GROUPED` followed by a new
shell prompt. It then enters `exit` and requires an additional
`LOGIN: ` prompt from INIT. Thus terminal echoing an input command
alone cannot produce a false PASS. The entire staged path has passed
in actual native PDP-6 SIMH.

Headless simulator runs disable optional DPY/WCNSLS/OCNSLS graphical
frontends to avoid host-side SDL/EGL/console errors; the DAIMOS
guest kernel, TTY, D6FS and storage code are not modified. A real
DSK root is selected with console switch `1` and 256K PDP-6 core.

## Remaining acceptance gates

The test establishes a functional minimal real-provider grouped
system, **not a full grouped-format release**. The entire standard
root filesystem and all optional user tools still require an
atomic grouped producer rebuild. Actual TSFS-root media, physical
PURE eviction/swap, nested provider-stack high-water, injected
I/O failures, and complete recovery regressions remain untested
end-to-end. The group format shares the existing DXR COMPRESSED bit
with D6LZ36; the two executable types must never be mixed on
production media. No permanent resident legacy fallback is present
in the grouped candidate.
