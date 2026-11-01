#!/bin/sh
# Full PDP-6: SYS_MEMINFO must count all 16 physical FILE slots.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-meminfo-fd16-v911.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
mkdir -p "$work/user"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -C -F -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
incs=""
for d in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $incs -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-meminfo-fd16-v911.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"

# A negative control uses a private kernel copy with the pre-v911 bug.
negative="${DAIMOS_V911_NEGATIVE:-0}"
case "$negative" in
    ''|0) negative=0 ;;
    1|capacity) negative=capacity ;;
    overwrite) ;;
    *) echo "v911: unknown negative mode $negative" >&2; exit 2 ;;
esac
kernel_dir="$DAIMOS_REPO/system/kernel"
if [ "$negative" != 0 ]; then
    kernel_dir="$work/source/system/kernel"
    mkdir -p "$work/source/system"
    cp -a "$DAIMOS_REPO/system/kernel" "$kernel_dir"
    cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
    cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
    python3 - "$kernel_dir/proc/syscall_info.s" "$negative" <<'EOFNEG'
from pathlib import Path
import sys
p=Path(sys.argv[1])
mode=sys.argv[2]
s=p.read_text()
if mode=='capacity':
    a='movei   4,020                   ; FILE_NFILE = 16 (octal 020)'
    b='movei   3,020                   ; same FILE_NFILE as the scan'
    assert s.count(a)==1 and s.count(b)==1
    s=s.replace(a,'movei   4,015',1)
    s=s.replace(b,'movei   3,015',1)
else:
    a='        movei   1,0                    ; count active FILE slots in place'
    b='        ; Count occupied slots and resident process+u-area words.'
    start=s.index(a)
    end=s.index(b,start)
    block=s[start:end]
    assert 'sys_meminfo_file_loop:' in block
    s=s[:start]+s[end:]
    anchor='''sys_meminfo:
        move    2,1                    ; validated info pointer
'''
    assert s.count(anchor)==1
    s=s.replace(anchor,anchor+block,1)
p.write_text(s)
EOFNEG
fi

build="$work/build/system/boot/pdp6"
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$kernel_dir" SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    >"$work/build.log" 2>&1 || {
        tail -60 "$work/build.log" >&2; exit 1
    }
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' "$build/boot.ini"
set +e
(cd "$build"; TERM=dumb timeout -k 2s 75s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -70 "$work/simh.out" >&2
    echo "v911: simulator exit $rc" >&2; exit 1
fi
text=$(tr -d '\r\n' < "$work/simh.out")
if [ "$negative" != 0 ]; then
    case "$negative:$text" in
        capacity:*'!1'*'HALT'*)
            echo 'v911: pre-fix 13-slot MEMINFO rejected (negative PASS)'
            exit 0 ;;
        overwrite:*'!4'*'HALT'*)
            echo 'v911: pre-fix FILE-count overwrite rejected (negative PASS)'
            exit 0 ;;
        *) tail -65 "$work/simh.out" >&2
           echo "v911: negative mode $negative did not fail as expected" >&2
           exit 1 ;;
    esac
fi
case "$text" in
    *'<'*'F'*'HALT'*) ;;
    *) tail -65 "$work/simh.out" >&2; echo 'v911: guest markers missing' >&2; exit 1 ;;
esac
case "$text" in
    *'!'*) tail -65 "$work/simh.out" >&2; echo 'v911: guest failure' >&2; exit 1 ;;
esac
echo 'v911: booted PDP-6 all 16 FILE slots and exact MEMINFO capacity PASS'
