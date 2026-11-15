# P1-D v1597: no Type-167 I/O processor, no phantom DRM mount slots

Date: 2026-11-15. Full 128K KCC PDP-6 with original physical
four-member DSK270 D6FSR2 root, original KINIT MINIT controller
probe and original FSINFO capacity handler. The existing 128K
XIP RUN/WAIT/EXEC regression also runs unchanged.

The initial diagnostic disabled only SIMH's Type-236 `DR` unit.
It failed the expected capacity-2 assertion, correctly: actual
DAIMOS `minit_drm236_probe` probes the upstream Type-167 `DP`
I/O processor with CONO/CONI device code `0010`; the `DP`
controller was still enabled, so the original KINIT had valid
DRM services and continued advertising six physical slots.
This was a **test inventory error**, not a production KCORE bug.

The corrected disposable SIMH boot script explicitly disables
both `DP` (the actual controller service) and `DR` (all its
drum units and attachments) *before* original MINIT executes.
The original KCORE services remain untouched. Original KINIT
now publishes capacity **2** (not 6): D6FS root provider 6
mount ID1 and MEMFS `/TEMP` provider 4 mount ID2; slots 2
and 3 are invalid, no phantom four DRM slots. Boot CTY
contains `DSK270 OK`, **no `DRM236 OK`**, `BSET LOADED`,
`MEMFS LOADED`, `D6FS LOADED`, and the guest marker
`P1D-D6FS-NODRM-CAPACITY2-V1597` followed by `XIP-RUN-PASS`
and `STATUS:0` and normal privileged HALT.

An independent raw disk/console oracle verifies all four
45,056-sector DSK270 D6FSR2 physical member descriptors,
independent member identities, matching geometry and actual
physical 128K RAM. **Four** unsafe controls are rejected:
incorrect physical D6FSR2 stamp, reused physical member,
missing guest FSINFO confirmation and invented DRM service.

The corrected physical guest and independent oracle PASS.
Evidence: `$TMPDIR/daimos-fsinfo-dsk-nodrm-v1597.VZeeOJ`
(full corrected reproducible runner) and
`$TMPDIR/daimos-p1d-v1597-run3.log`; an earlier image-only
DP+DR-disabled rerun is retained under
`$TMPDIR/daimos-fsinfo-dsk-nodrm-v1597.pIvTbI/guest/run-v1597-dpabsent`.

Reproduce:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
V1597_KEEP_WORK=1 sh \
    tests/validation/daimos-fsinfo-dsk-no-drm-physical-v1597.sh
```

This accepts a genuinely absent controller-service physical
inventory, not merely an empty disk or fictional mount capacity.
Previous accepted TSFS two/three-member roots publish 8/7 slots,
and four-member DSK/DRM roots with both storage controllers
publish six slots. Other service-removal/fault combinations remain
subject to final acceptance. No production RAM/ABI/code change;
VERSION 0.5, 32K and P1-E KA10 decisions remain on hold.
