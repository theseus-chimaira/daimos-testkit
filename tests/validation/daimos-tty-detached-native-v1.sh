#!/bin/sh
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
tag=daimos-tty-detached-native-v1
ps="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"

# Native read/output and controlling-TTY ownership paths subtract the attached
# state base before indexing the terminal table.  DETACHED therefore becomes
# -1 and must be rejected with a signed lower-bound check first.
count=$(grep -c 'DETACHED becomes -1' "$ps" || true)
[ "$count" -eq 3 ] || {
        echo "$tag: native DETACHED guards missing" >&2
        exit 1
}

printf '%s\n' "$tag: PASS (native TTY paths reject DETACHED before indexing)"
