#!/bin/sh
# Test-only altered PID1; original KCORE/child and physical MM are unchanged.
set -eu
: "${DAIMOS_REPO:?source PURE checkout required}"
: "${V1679_FIXTURE:?absolute versioned directory required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir -p "$V1679_FIXTURE"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
link="$PDP10_PREFIX/bin/dlink"
incs="-I$DAIMOS_REPO/userland/libc"
for dir in proc core boot fs drivers modules storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
incs="$incs -I$PDP10_PREFIX/include"
for part in crt0 syscall; do
    "$das" -F -C -O "$V1679_FIXTURE/$part.dobj" \
        "$DAIMOS_REPO/userland/libc/$part.s"
done
"$cc" -std=c89 -Os $incs -S \
    "$DAIMOS_REPO/userland/libc/u.c" -o "$V1679_FIXTURE/u.s"
"$das" -F -C -O "$V1679_FIXTURE/u.dobj" "$V1679_FIXTURE/u.s"
"$cc" -std=c89 -Os $incs -S \
    "$here/proc-pressure-v1679.c" -o "$V1679_FIXTURE/pressure.s"
"$das" -F -C -O "$V1679_FIXTURE/pressure.dobj" \
    "$V1679_FIXTURE/pressure.s"
"$das" -F -C -O "$V1679_FIXTURE/checkpoint.dobj" \
    "$here/../pure-runtime-reclaim-v1673/checkpoint-v1673.s"
"$das" -F -C -O "$V1679_FIXTURE/sleep-child.dobj" \
    "$here/../pure-runtime-highwater-v1674/pipe-child-v1674.s"
"$link" -b 020 --pure -o "$V1679_FIXTURE/v1673-test-sleep.dxr" \
    -M "$V1679_FIXTURE/v1673-test-sleep.map" \
    "$V1679_FIXTURE/sleep-child.dobj"
libgcc=$("$cc" -print-libgcc-file-name)
"$link" -b 020 -o "$V1679_FIXTURE/v1673-test-init.dxr" \
    -M "$V1679_FIXTURE/v1673-test-init.map" \
    "$V1679_FIXTURE/crt0.dobj" "$V1679_FIXTURE/syscall.dobj" \
    "$V1679_FIXTURE/u.dobj" "$V1679_FIXTURE/pressure.dobj" \
    "$V1679_FIXTURE/checkpoint.dobj" "$libgcc"
for name in v1673_before v1673_pressure v1673_reaped; do
    grep -q "^$name[[:space:]]" "$V1679_FIXTURE/v1673-test-init.map"
done
echo "PASS v1679: source-built repeated-RUN PID1 $V1679_FIXTURE"
