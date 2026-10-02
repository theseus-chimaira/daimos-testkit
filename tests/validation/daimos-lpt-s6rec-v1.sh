#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
tag=daimos-lpt-s6rec-v1
work="$TMPDIR/$tag-$$"; build="$work/build"; user="$work/user"; out="$work/simh.out"
mkdir -p "$user"; trap 'rm -rf "$work"' EXIT HUP INT TERM
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"; das="$PDP10_PREFIX/bin/das"; dlink="$PDP10_PREFIX/bin/dlink"
"$cc" -std=c99 -Os -I"$DAIMOS_REPO/system/kernel/boot" -I"$DAIMOS_REPO/system/kernel/core" -I"$DAIMOS_REPO/system/kernel/drivers" -I"$DAIMOS_REPO/system/kernel/fs" -I"$DAIMOS_REPO/system/kernel/ipc" -I"$DAIMOS_REPO/system/kernel/mm" -I"$DAIMOS_REPO/system/kernel/modules" -I"$DAIMOS_REPO/system/kernel/proc" -I"$DAIMOS_REPO/system/kernel/storage" -I"$DAIMOS_REPO/userland/libc" -S "$(dirname "$0")/daimos-lpt-s6rec-v1.c" -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"; "$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"; "$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name); "$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"
PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null
boot="$build/system/boot/pdp6"; lpt="$boot/media/lpt.out"
set +e; (cd "$boot"; TERM=dumb timeout -k 2s 45s stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$out" 2>&1; rc=$?; set -e
[ "$rc" -eq 0 ] || { cat "$out" >&2; exit 1; }
case "$(tr -d '\r\n' <"$out")" in *'!'*) cat "$out" >&2; exit 1;; *'LPASS'*'HALT'*) ;; *) cat "$out" >&2; exit 1;; esac
[ -f "$lpt" ] || { echo "$tag: LPT output missing" >&2; exit 1; }
text=$(tr -d '\r\n' <"$lpt")
[ "$text" = 'HELLO WORLD' ] || { od -An -v -tx1 "$lpt" >&2; echo "$tag: wrong LPT output: $text" >&2; exit 1; }
printf '%s\n' "$tag: PASS (S6REC -> packed five-character LP10 output)"
