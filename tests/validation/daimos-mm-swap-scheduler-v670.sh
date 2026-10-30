#!/bin/sh
# Isolate a CLEAN full-system swap boot image before running v669 pressure.
# Never reuse media changed by a prior interrupted PDP-6 simulator run.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${DAIMOS_SWAP_BOOT_V670:?path to a freshly built 256K boot image}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
source_boot=$DAIMOS_SWAP_BOOT_V670
tag=daimos-mm-swap-scheduler-v670
work=$(mktemp -d "$TMPDIR/$tag.XXXXXX")
trap 'if [ "${DAIMOS_SWAP_KEEP_V670:-0}" = 1 ]; then echo "$tag: retained $work" >&2; else rm -rf "$work"; fi' EXIT HUP INT TERM

[ -f "$source_boot/boot.ini" ] &&
[ -f "$source_boot/kcore.map" ] &&
[ -f "$source_boot/swap-mres-v481.map" ] &&
[ -d "$source_boot/disk" ] || {
    echo "$tag: incomplete full-system boot fixture" >&2
    exit 1
}
ck=$PDP10_PREFIX/bin/d6fsck
[ -x "$ck" ] || { echo "$tag: missing d6fsck" >&2; exit 1; }
if ! "$ck" -n 4 -d "$source_boot/disk" >"$work/source-check.log" 2>&1; then
    cat "$work/source-check.log" >&2
    echo "$tag: source media DIRTY or invalid; rebuild, do not reuse" >&2
    exit 1
fi

boot=$work/boot
mkdir -p "$boot"
cp -a "$source_boot/disk" "$boot/disk"
if [ -d "$source_boot/drum" ]; then
    cp -a "$source_boot/drum" "$boot/drum"
fi
for name in kcore.map swap-mres-v481.map; do
    cp "$source_boot/$name" "$boot/$name"
done
if [ -f "$source_boot/swap-pressure-init-v737.sha256" ]; then
    cp "$source_boot/swap-pressure-init-v737.sha256" "$boot/"
fi
# Replace *only* the attached writable media paths and simulator log.
# Stage-1 PTR/boot payloads remain read-only at their original locations.
python3 - "$source_boot" "$boot" <<'PY'
from pathlib import Path
import sys
source, destination = map(Path, sys.argv[1:])
data = (source / 'boot.ini').read_text()
for medium in ('disk', 'drum'):
    data = data.replace(str(source / medium) + '/', str(destination / medium) + '/')
data = data.replace(str(source / 'boot.simh.log'),
                    str(destination / 'boot.simh.log'))
(destination / 'boot.ini').write_text(data)
PY
if ! "$ck" -n 4 -d "$boot/disk" >"$work/staged-check.log" 2>&1; then
    cat "$work/staged-check.log" >&2
    echo "$tag: staged media unexpectedly invalid" >&2
    exit 1
fi
echo "$tag: CLEAN media isolated; original disks will not be modified"
if [ "${DAIMOS_SWAP_PREFLIGHT_ONLY_V670:-0}" = 1 ]; then
    echo "$tag: preflight PASS (scheduler workload not executed)"
    exit 0
fi

DAIMOS_SWAP_BOOT_V669=$boot \
    sh "$self/daimos-mm-swap-scheduler-v669.sh"
