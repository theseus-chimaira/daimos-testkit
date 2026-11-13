#!/bin/sh
# One-process full PDP-6 guest acceptance for the installed DTFS MRES.
# The test's tiny userspace process is linked against the exact already
# built production libc and directly tests the actual kernel syscalls.
# A separate root-tape program load is not needed for each assertion.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO required}"
: "${PDP10_PREFIX:?PDP10_PREFIX required}"
: "${TMPDIR:=${HOME}/tmp}"
: "${DAIMOS_TSFS_PREBUILT_BUILD:?prebuilt DTC-root KCC image required}"
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-gate-build-v1525.XXXXXX")
b="$DAIMOS_TSFS_PREBUILT_BUILD"
trap 'if [ "${DAIMOS_TSFS_KEEP_WORK:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM

gate_source=${DAIMOS_TSFS_GATE_SOURCE_V1526:-"$self/../target/daimos-dtfs-physical-gate-v1525.c"}
cp "$gate_source" "$work/gate.c"
incs=
for d in boot core drivers fs mm modules proc storage; do
        incs="$incs -I$DAIMOS_REPO/system/kernel/$d"
done
incs="$incs -I$DAIMOS_REPO/userland/libc"
incs="$incs -I$PDP10_PREFIX/include"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs \
        -S "$work/gate.c" -o "$work/gate.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/gate.dobj" "$work/gate.s"
base="$b/userland/command/libc"
"$PDP10_PREFIX/bin/dlink" --daimos-uuo-relax -b 020 \
        -o "$work/gate.dxr" -M "$work/gate.map" \
        "$base/crt0.dobj" "$base/syscall.dobj" \
        "$base/syscall_helpers.dobj" "$work/gate.dobj" \
        "$base/u.dobj" "$base/text.dobj"
"$PDP10_PREFIX/bin/dxrcheck" "$work/gate.dxr"
"$b/d6block-v1464" -x "$work/gate.dxr" "$work/gate.block.dxr"

export DAIMOS_TSFS_GATE_BINARY_V1525="$work/gate.block.dxr"
export DAIMOS_TSFS_GATE_DXR_V1525="$work/gate.dxr"
export DAIMOS_TSFS_GATE_RUN_V1525=1
export DAIMOS_TSFS_GATE_INIT_V1525=1
export DAIMOS_TSFS_MINIMAL_ROOT_V1525=1
export DAIMOS_TSFS_MOUNT_PREFORMATTED_V1525=1
sh "$self/daimos-dtfs-tape-root-mount-v578.sh"
