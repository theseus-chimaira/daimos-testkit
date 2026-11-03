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

The old `run-type340-text-v1.sh` and `type340-text-v1.c` were moved
unchanged into `tests/archive/type340-c-obsolete-v1056/` on 2026-11-03.
They include `dpy_text.c`, deleted when the retained Type 340/342
terminal was rewritten in native assembler. They cannot validate the
current code and must not be run as acceptance tests. The active
`test-daimos-dpy-native-blocks` regression replaces the old C fixture.
The filesystem metadata script resolves the repository root from its
deeper location.

The mktap seven-track test was moved here because it validates magnetic
tape output rather than processor behavior.
