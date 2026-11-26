#!/bin/sh
# Exact v1951 nine-owner geometry, current KCC GENERAL or STRICT image.
set -eu
test "$#" = 3 || { echo "usage: $0 BUILD FIXTURE WORK" >&2; exit 2; }
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export V1673_GROWN_CHILDREN=2
b=$(cd "$1" && pwd)
f=$(cd "$2" && pwd)
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
grep -Fxq "F /SYSTEM/INIT $f/v1673-test-init.dxr 0555 0 0" "$b/tsfs-root.manifest"
grep -Fxq "F /SYSTEM/EXEC/MOUNTALL $f/v1673-test-sleep.dxr 0555 0 0" "$b/tsfs-root.manifest"
V1957_DATA_MEMBER=1 sh "$here/prepare-v1957.sh" "$b" "$3"
w=$(cd "$3" && pwd)
python3 "$here/../pure-runtime-highwater-v1674/host-cty-v1674.py" \
    "$w/pty-run" "$PDP10_PREFIX/bin/pdp6" "$w/headless.ini" \
    "$b/kcore.map" "$w/console.log" "${V1673_TIMEOUT:-1800}" "$b"
sha256sum -c "$w/source.sha256"
python3 "$here/../pure-runtime-reclaim-v1673/measure-v1673.py" \
    "$f/v1673-test-init.map" "$b/kcore.map" "$w/console.clean" 48 "$w/physical.json"
python3 "$here/../pure-runtime-highwater-v1674/trace-v1674.py" \
    "$f/v1673-test-init.map" "$b/kcore.map" "$w/console.clean" "$w/physical.json" "$w/highwater.json"
python3 "$here/verify-owners-v1957.py" \
    "$f/v1673-test-init.map" "$b/kcore.map" "$w/console.clean"
