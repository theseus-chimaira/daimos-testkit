# K07 acceptance checkpoint, v1940

Production source: DAIMOS 7a87d843, initial testkit da09056.
No production kernel code was changed.

    export DAIMOS_REPO=$HOME/git/DAIMOS
    export PDP10_PREFIX=$HOME/cross TMPDIR=${TMPDIR:-$HOME/tmp}
    make test-pure-k07-native-v1940

All 13 distinct native regression groups passed independently, using
the same make targets as the consolidated runner. The D6FS discard
gate also contains the previous D6FS media/loss/normal retirement
native matrix. The wrapper was syntax-checked; the actual v1940
execution used parallel individual targets. No repeated execution
of the identical D6FS negative controls is necessary for this matrix.
Evidence: $TMPDIR/k07-accept-v1940.ENLgJ9/*.log and *.result.

Full guest, original mixed plain/compressed TSFS workload:

    make test-pure-k07-physical-v1940

A current source-built 48K GCC lowmem TSFS guest initially could not
build because the installed native KCC bootstrap was absent. Restored
the five actual phase executables using KCC edff620's existing
make install-native PREFIX=$PDP10_PREFIX PDP10_PREFIX=$PDP10_PREFIX
DAIMOS_REPO=$DAIMOS_REPO. No compiler source changes. The image was
then built successfully, and the exact plain/compressed DXR2 fixture
and three-member TSFS media verified (54 files, 315 extents).

The unmodified guest installed PURE and DTFS, started PID1, and
printed aaa (one plain and two compressed child RUNs checked sleeping)
before the 180-second host diagnostic timeout (exit 124). No normal
HALT, all-child WAIT or physical FULL restore is claimed. A separate
private-media monitor probe stopped after the DTFS banner and stepped
three bounded 100000-instruction intervals. The sampled PCs 032065,
032071 and 032073 are consistent with the DTC search loop; the last
uninterrupted run reached PC 032073 at SIGTERM. This is a slow
progressing boot/workload, not evidence of a proven deadlock.
The wrapper restores a more appropriate 1150-second default and
requires all six successful RUNs, seventh refusal, six child exit
markers and normal HALT in addition to the original lifecycle checks.
The wrapper's longer acceptance run has not yet been executed.

GCC physical build:
- KCORE SHA256 4177db78eabee2b54a1cb3d6e2cec3eee6e4b0b2d9e330a22f3d6acf052c85e1
- PURE SHA256 e488f1a93315ff7039326c948d1e9b39632507850c999fffa1285f975c6b0c41
- INIT SHA256 ea5b1e9973af6e136bf213a52088569f4d6dd25521bbb858e6f071c9a58763bc
- COMP SHA256 3379172c8026f9e2245e626a01395561d7096620da39af0b6b67a17276dd17ec

Original build and console: $TMPDIR/pure-brk-pressure-v1614.Fx9gcX.
Probe: $TMPDIR/k07-accept-v1940.ENLgJ9/probe.log, probe-headless.ini.
The historical v1638/v1647 physical replay's fixed offsets do not
match current images. Derive from current map/installed MRES bindings
and verify actual owner geometry rather than reusing those addresses.

K07 remains OPEN: complete physical pressure/restore, real PI6
reservation/retirement and source-loss recovery acceptance. Existing
native tests control selected MM, physical I/O and scheduler boundaries.
No claim of additional RAM savings or changed default feature policy.
