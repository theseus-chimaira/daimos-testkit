# DAIMOS regressions relocated from pdp10-testkit (v1)

These 17 files were migrated from the generic bare-metal CPU testkit.
They depend on DAIMOS source, boot images, runtime, filesystems, display
hardware, or peripheral-media utilities. This directory retains original
script basenames to preserve regression identifiers.

Run shell scripts from the daimos-testkit repository root. Set `TMPDIR`,
`PDP10_PREFIX`, and `DAIMOS_REPO` as required by each script. The native
runtime scripts also require `DAS_ROOT` and a suitable installed PDP-6
simulator. This initial relocation does not add the suites to the regular
DAIMOS acceptance matrix. Integrate each test only after validating its
prerequisites and expected outputs in the destination environment.

`run-type340-text-v1.sh` uses its relocated source path. The filesystem
metadata script now resolves the repository root from its deeper location.

The mktap seven-track test was moved here because it validates magnetic
tape output rather than processor behavior.
