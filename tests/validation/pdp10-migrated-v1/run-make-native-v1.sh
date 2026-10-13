#!/bin/sh
set -eu

fail()
{
    echo "run-make-native-v1: $*" >&2
    exit 1
}

TEST_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PDP10_PREFIX=${PDP10_PREFIX:?set PDP10_PREFIX}
DAIMOS_REPO=${DAIMOS_REPO:?set DAIMOS_REPO}
DAS_ROOT=${DAS_ROOT:?set DAS_ROOT}
TMPDIR=${TMPDIR:?set TMPDIR}

work=$TMPDIR/make-native-v1-$$
build=$work/build
user=$work/user
text=$work/MAKEFILE
s6=$work/MAKEFILE.s6rec
out=$work/simh.out
mkdir -p "$user"
trap 'rm -rf "$work"' 0 1 2 3 15

kcc=$PDP10_PREFIX/bin/kcc
das=$DAS_ROOT/das
dlink=$PDP10_PREFIX/bin/dlink
simh=$PDP10_PREFIX/bin/pdp6

incs="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/userland/libc -I$PDP10_PREFIX/include"

"$kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs -S \
    "$TEST_ROOT/make-native-v1.c" -o "$user/init.s"
"$das" -F -C -O "$user/init.dobj" "$user/init.s"
"$das" -F -C -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$das" -F -C -O "$user/syscall_helpers.dobj" \
    "$DAIMOS_REPO/userland/libc/syscall_helpers.s"
"$dlink" --daimos-uuo-relax -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/syscall_helpers.dobj" \
    "$user/init.dobj"

cat > "$text" <<'EOF'
OUT = /TEMP/WRONG
.PHONY: FORCE
$(OUT): /TEMP/SRC
> TOUCH $@
FORCE:
> TOUCH /TEMP/PHONY
.C.O:
> TOUCH $@
EOF
"$DAS_ROOT/s6text" --encode "$text" "$s6"

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
    DAS="$DAS_ROOT/das" DASFLAGS=-F DAS_REPO="$DAS_ROOT" \
    PROC_BOOT_USERS=1 D6FS_LOGSTORE_BLOCKS=010 D6FS_SWAP_TAIL_BLOCKS=010 \
    SYSTEM_INIT_DXR="$user/init.dxr" \
    D6FS_EXTRA_ARGS="-f /TEMP/MAKEFILE:$s6:644:binwords" >/dev/null

boot=$build/system/boot/pdp6
set +e
(
    cd "$boot"
    TERM=dumb timeout -k 2s 60s stdbuf -o0 -e0 "$simh" boot.ini
) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    cat "$out" >&2
    fail "simulator failed: $rc"
fi
if ! tr -d '\r' < "$out" | grep -F 'MAKE NATIVE PASS' >/dev/null; then
    cat "$out" >&2
    fail "native MAKE contract failed"
fi
if tr -d '\r' < "$out" | grep -F 'MAKE NATIVE FAIL' >/dev/null; then
    cat "$out" >&2
    fail "native MAKE target reported failure"
fi

echo "native MAKE dependency/mtime/suffix contract passed"
