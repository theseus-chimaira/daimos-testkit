#!/bin/sh
# Build only the PDP-6 image; run SIMH/recovery in the acceptance wrapper.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
: "${TMPDIR:=$HOME/tmp}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-d6fs-live-operation-cut-20261012-v1.XXXXXXXX")
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
incs="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/userland/libc"
"$das" -F -C -O "$work/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$work/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$cc" -std=c99 -Os $incs -S "$DAIMOS_REPO/userland/libc/u.c" -o "$work/u.s"
"$das" -F -C -O "$work/u.dobj" "$work/u.s"
"$cc" -std=c99 -Os $incs -S "$self/daimos-d6fs-live-operation-cut-20261012-v1.c" -o "$work/test.s"
"$das" -F -C -O "$work/test.dobj" "$work/test.s"
"$PDP10_PREFIX/bin/dlink" -b 020 -o "$work/test.dxr" -M "$work/test.map" \
    "$work/crt0.dobj" "$work/syscall.dobj" "$work/u.dobj" "$work/test.dobj" "$($cc -print-libgcc-file-name)"
"$cc" -std=c99 -Os $incs -S "$self/daimos-d6fs-live-operation-verify-20261012-v1.c" -o "$work/verify.s"
"$das" -F -C -O "$work/verify.dobj" "$work/verify.s"
"$PDP10_PREFIX/bin/dlink" -b 020 -o "$work/verify.dxr" -M "$work/verify.map" \
    "$work/crt0.dobj" "$work/syscall.dobj" "$work/u.dobj" "$work/verify.dobj" "$($cc -print-libgcc-file-name)"
python3 - "$work/seed.bin" <<'PY'
import sys
with open(sys.argv[1], 'wb') as stream:
    stream.write((0o123456701234).to_bytes(8, 'little'))
PY
FAULT_HALT_AFTER_FIRST_WORD=0o123456701234 \
    D6FS_EXTRA_ARGS="-f /CONFIG/FAULT.TEST:$work/test.dxr:555:dxr -f /CONFIG/FCBSEED:$work/seed.bin:666:binwords -f /CONFIG/VERIFY.TEST:$work/verify.dxr:555:dxr" \
    "$self/daimos-d6fs-fault-link-20261012-v1.sh" > "$work/image-location.txt"
image=$(sed -n 's/^INJECTED_IMAGE=//p' "$work/image-location.txt")
injected=$(sed -n 's/^INJECTED_WORK=//p' "$work/image-location.txt")
test -f "$image"
printf 'CUT_IMAGE=%s\nCUT_DISK=%s\nCUT_BUILD=%s\nCUT_WORK=%s\n' "$image" "$injected/image/system/boot/pdp6/disk" "$injected" "$work"
