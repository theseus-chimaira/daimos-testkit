# Experimental real DSH qualification (v1995)

Use the source-built 48K strict swapless TSFS images described in the
sibling lifecycle48 test and their matching GCC userland build root.
Set DAIMOS_REPO, PDP10_PREFIX and TMPDIR.

    sh tests/validation/pure-directory-dsh-v1995/run-v1995.sh "$BUILD" "$USERLAND_BUILD_ROOT" directory

Use raw instead of directory for a matching RAW build. The script creates
private tapes and marks only its test DSH DXR2. It requires the complete
payload and relocation bitmap to match the normal executable exactly;
only PURE and mutable compression flags may differ. It checks retained
shell state across external commands and clean HALT/media integrity.
V1995_BOOT_TIMEOUT and V1995_COMMAND_TIMEOUT select bounded harness
limits (default 300 and 120 seconds). The probe is experimental, not an
accepted mode3 DSH witness: a successful shell command alone does not
establish that DSH was packed and restored.

First directory run on af048d25 reached actual ROOT login and DSH V1;
SET KEEP passed, but ECHO VALUE:$KEEP timed out with the original
45-second command limit. Login startup exceeded two minutes. First RAW
run was stopped before login; interrupting a dofile with trailing exit
also exited the simulator. No diagnosis of a compression defect follows
from these observations. No production DSH flags are changed.
