# v1543: physical DRM236 D6FS-root outage

Date: 2026-11-13. Full physical PDP-6 root fail-stop qualification.
Only daimos-testkit changes; the original v1538 KCORE root gate is
unchanged. Not an optimization or a hardware absence-bit detector.

## Full-guest acceptance

The testkit builds an isolated, normal KCC 256K PDP-6 image with
`ROOT=drum`, `BOOT=drm`, and four actual `mkdsk`/`mkd6fs` D6FS drum
members. A real `/SYSTEM/INIT` PID1 executable first STATs the
selected root's `/SYSTEM/INIT`, `/SYSTEM`, `/CONFIG`, then reaches
`ROOTLOSS V1538 READY_DETACH` after D6FS and DRM236 are loaded.
SIMH console switch octal 3 selects the **DRM** root controller,
not the independently attached DSK270 devices.

The host interrupts SIMH, detaches **DR0, DR1, DR2, DR3** only,
and resumes through the existing delayed CTY input. PID1 opens and
reads required root file data to force uncached physical I/O rather
than trusting warm STAT metadata. The actual PDP-6 HALTs at octal
**003743**, equal to the production linked v1515 entry `003740+3`
(the ROOT HALT). The BACKSTORE HALT at `003747` and a userspace
stop at PC zero are rejected. Wrong/multiple/no HALT and explicit
PID1 failure text are also rejected.

The full ROOT=drum image, normal stage1 DRM boot, actual selected
root file read and physical detach path **PASS**. Source-only
native tests were not substituted for this physical guest.

Run:

```
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
sh tests/validation/daimos-drm-root-outage-fullguest-v1543.sh
```

The v1543 wrapper uses the same versioned real PID1/root-HALT oracle
as accepted disk-root v1540. The only differences are the complete
drum-root build, DRM stage1, root selector, and physical DR0..DR3
detach commands. The old disk-root test still selects DSK0..DSK3.

## Limits

This is positive **selected DRM-root** loss. Physically unrelated
secondary DSK/DRM faults under another active root, plus combined
ROOT/BACKSTORE DEVICE/VOLUME faults, remain open. Do not infer that
mere detachment of an unused device constitutes failed mounted
secondary filesystem I/O. No production code, ABI or data changed.
