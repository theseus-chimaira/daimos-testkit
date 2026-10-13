#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
out="$TMPDIR/d6codec-stage1-v072-test"
mkdir -p "$out"
for device in dsk drm dtc mtc ptr; do
    "$PDP10_PREFIX/bin/das" -F -K \
        -O "$out/stage1-${device}-v072.dxr" \
        "$DAIMOS_REPO/system/stand/pdp6/$device/stage1-inline-v072.s"
    test -s "$out/stage1-${device}-v072.dxr"
done
printf '%s\n' 'PASS all five inline Stage-1 v072 DAS assemblies'
