#!/bin/sh
# Verify actual boot of MEMFS in the 64K+ low-memory profile.
# This checks only the mount milestone, not complete LOGIN acceptance.
set -eu
log=${1:?usage: check-memfs-boot-v138.sh PDP6-boot.log}
tmp=${TMPDIR:-$HOME/tmp}/memfs-boot-check-v138-$$
trap 'rm -f "$tmp"' EXIT HUP INT TERM
tr -d '\r' < "$log" > "$tmp"
for milestone in 'MEMFS' 'D6FS' 'INIT V1'; do
    grep -F "$milestone" "$tmp" >/dev/null || {
        echo "FAIL: missing $milestone boot milestone" >&2
        exit 1
    }
done
if grep -E 'INIT: WARNING: MEMFS NOT MOUNTED|\?RT' "$tmp" >/dev/null; then
    echo 'FAIL: MEMFS mount or root selection failed' >&2
    exit 1
fi
echo 'PASS: MEMFS installed and /TEMP mount warning absent'
