#!/bin/sh
# Rebuild ONLY source-derived guest DXR/TSFS on a disposable v1646 KCORE.
# Keep the original test-only v1565 scheduler interval and all original
# kernel/MM/provider code binary-identical across fixture iterations.
set -eu
: "${DAIMOS_REPO:?original source checkout required}"
: "${PURE_QUIESCE_WORK_V1646:?disposable test-only KCORE work directory required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$PURE_QUIESCE_WORK_V1646
test -s "$work/build/kcore.map"
grep -q '^vfs_quiesce_sleep_done_v1646[[:space:]]' \
    "$work/build/kcore.map"
python3 "$here/check-v2-v1647.py" \
    "$work/build/media/dtc3-home-v22.tap"
mkdir -p "$work/user"
python3 "$here/prepare-v1646.py" \
    "$testkit/tests/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/user/init-v1646.c"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$work/dlink-v1646"
${HOST_CC:-cc} -std=c89 -O2 -Wall -Wextra -Werror \
    -o "$dlink" "$DAIMOS_REPO/tools/host/dlink.c" \
    "$DAIMOS_REPO/tools/host/dobj.c"
incs=
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
incs="$incs -I$DAIMOS_REPO/userland/libc"
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $incs -S "$work/user/init-v1646.c" \
    -o "$work/user/init-v1646.s"
"$das" -C -F -O "$work/user/init-v1646.dobj" \
    "$work/user/init-v1646.s"
"$das" -C -F -O "$work/user/crt0-v1646.dobj" \
    "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall-v1646.dobj" \
    "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$("$cc" -print-libgcc-file-name)
test -s "$work/user/init.dxr"
cp "$work/user/init.dxr" "$work/user/init-prebrk-v1646.dxr"
"$dlink" --pure -b 020 -o "$work/user/init.dxr" \
    -M "$work/user/init-v1646.map" \
    "$work/user/crt0-v1646.dobj" \
    "$work/user/syscall-v1646.dobj" \
    "$work/user/init-v1646.dobj" "$libgcc"
"$PDP10_PREFIX/bin/dxrcheck" -d "$work/user/init.dxr" \
    >"$work/user/dxrcheck-v1646.log"
grep -q 'purity=PURE' "$work/user/dxrcheck-v1646.log"

sh "$testkit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh" \
    "$work" "$work/build"
test -s "$work/user/comp-v1638.dxr"
test -s "$work/build/media/dtc0.tap"
grep -q 'F /SYSTEM/INIT' "$work/build/tsfs-root.manifest"
echo "PASS v1646: corrected no-growth BRK C89 guest and REAL TSFS tapes rebuilt"
echo "v1646: unchanged original-plus-test-sleep KCORE map=$work/build/kcore.map"
