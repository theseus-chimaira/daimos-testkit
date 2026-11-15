# P1-D v1594: DSK270-selected four-member physical root FSINFO

Date: 2026-11-15. Full 128K KCC PDP-6 boots a genuine D6FSR2 root
from original DSK270 DSK0..DSK3 hardware simulation. All production
KINIT inventory/root selection, six-array MM mount slab, original
FSINFO syscall and XIP RUN/WAIT/EXEC operations are unchanged.

The opt-in v1594 C89 XIP guest queries FSINFO capacity through the
original `dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0)`. It requires **6**:
one four-member disk root, four spare DRM236 transport positions,
and one MEMFS mount. It checks slot 0 D6FS provider 6/root ID 1,
slot 1 MEMFS provider 4/`/TEMP` public ID 2, holes 2..5, invalid
6 and 7, and stable capacity. The guest emits
`P1D-D6FS-DSK-CAPACITY6-V1594` only after all conditions pass.
It then completes the original full XIP/EXEC/RUN/WAIT test.

The first experiment returned correct D6FS/FSINFO and XIP markers
but detected default listener-port collisions with an independent
PDP-6 test and could not be accepted. The test fixture now derives
independent DCS/GE ports per run and refuses ANY SIMH listener or
device-attachment error. The corrected complete guest **PASSes**.
This is a test-harness isolation fix, not a device or kernel bypass.

An independent post-HALT verifier checks actual simulator 128K
memory, DSK270 and DRM236 controller probes, real D6FS/MEMFS
loading, the FSINFO stage, original XIP success, a single HALT,
and absence of simulation errors. It opens all four real DSK files,
reads the original packed 36-bit sector-zero descriptors and verifies
the drive marker, the D6FSR2 member marker, four distinct member
identities, identical valid original volume geometry and 36-bit
word bounds. Each disk has 45,056 sectors, with D6FSR2 geometry
base `000001`, span `127377`, tail `000400` octal. Three unsafe
controls (missing real root marker, duplicated member identity,
missing FSINFO result) must fail the independent oracle.

Retained evidence:
`$TMPDIR/daimos-fsinfo-dsk-root-v1594.h6HlfZ` including four real
DSK270 images, SIMH transcript, root build, original XIP guest
binary and `v1594-physical-verification.txt`. Corrected runner
output: `$TMPDIR/daimos-p1d-v1594-run2.log`.

Reproduce:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
V1594_KEEP_WORK=1 sh \
    tests/validation/daimos-fsinfo-dsk-root-physical-v1594.sh
```

P1-D now has physical root acceptance for TSFS on DTC (capacity
7/8), D6FS on DRM236 (capacity 6, v1593), and D6FS on DSK270
(capacity 6, v1594). The 26-slot limit remains a representational
bound, not actual 26-drive acceptance. P1-D remains open for
unavailable/failed provider inventory and mounted high-slot errors
under alternate physical hardware. No installed KCORE RAM/code,
ABI or on-media format change. P1-E architecture is held for KA10.
