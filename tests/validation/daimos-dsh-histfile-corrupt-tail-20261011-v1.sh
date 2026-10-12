#!/bin/sh
# Deterministic two-open D6FS append acceptance on a fresh PDP-6 image.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
: "${TMPDIR:=$HOME/tmp}"
tag=daimos-dsh-histfile-corrupt-tail-20261011-v1
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="$TMPDIR/$tag-$$"
obj="$work/obj"
build="$work/build"
mkdir -p "$obj"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
incs="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core"
incs="$incs -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs"
incs="$incs -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules"
incs="$incs -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage"
incs="$incs -I$DAIMOS_REPO/userland/libc"
"$das" -F -C -O "$obj/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$obj/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$cc" -std=c99 -Os $incs -S "$DAIMOS_REPO/userland/libc/u.c" -o "$obj/u.s"
"$das" -F -C -O "$obj/u.dobj" "$obj/u.s"
"$cc" -std=c99 -Os $incs -S "$self/$tag.c" -o "$obj/test.s"
"$das" -F -C -O "$obj/test.dobj" "$obj/test.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$obj/test.dxr" -M "$obj/test.map" \
    "$obj/crt0.dobj" "$obj/syscall.dobj" "$obj/u.dobj" "$obj/test.dobj" "$libgcc"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -o "$work/pty-run" \
    "$self/../../tools/pty-run-v1.c"
cat > "$work/probes.txt" <<'PROBES'
probe seed-truncated-tail
command /CONFIG/HISTCOR.TEST
contains HISTCOR-SEED-PASS
end
probe orderly-halt
command HALT
terminal eof
end
PROBES
# The next ROOT login is interactive, so DSH loads HISTFILE at startup.
printf 'probe recall-valid-prefix\ncommand \020\ncontains ECHO SAFE\nend\nprobe orderly-halt-reboot\ncommand HALT\nterminal eof\nend\n' > "$work/reboot-probes.txt"
# The second boot appends HALT after recalling ECHO SAFE; on the third boot
# the newest entry is HALT, so two UP/CTRL-P presses reach ECHO SAFE.
printf 'probe recall-valid-prefix-again\ncommand \020\020\ncontains ECHO SAFE\nend\nprobe orderly-halt-final\ncommand HALT\nterminal eof\nend\n' > "$work/repaired-probes.txt"
host_tools="${DAIMOS_HOST_TOOLS:-$PDP10_PREFIX/bin}"
PATH="$host_tools:$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    HOST_TOOLS="$host_tools" DAS_REPO="${DAS_REPO:-$DAIMOS_REPO/../das}" \
    KCC_REPO="${KCC_REPO:-$DAIMOS_REPO/../kcc}" \
    PDP10_KCC="$PDP10_PREFIX/bin/kcc" \
    MKBOOTBANNER="$host_tools/mkbootbanner" \
    P10FOLD="$host_tools/p10fold" MKDSK="$host_tools/mkdsk" \
    MKD6FS="$host_tools/mkd6fs" \
    DSH_IMAGE_LIMIT=037000 BOOT=dsk ROOT=disk ROOTSET=1 \
    D6FS_EXTRA_ARGS="-f /CONFIG/HISTCOR.TEST:$obj/test.dxr:555:dxr" \
    > "$work/image-build.log" 2>&1 || {
        tail -35 "$work/image-build.log" >&2
        exit 1
    }
"$self/../../tools/daimos-simh-harness-v6.sh" \
    --daimos-repo "$DAIMOS_REPO" \
    --dofile "$build/system/boot/pdp6/boot.ini" \
    --pty-run "$work/pty-run" --login ROOT --probes "$work/probes.txt" \
    --work-dir "$work/run" --boot-timeout 45 --timeout 20
"$self/../../tools/daimos-simh-harness-v6.sh" \
    --daimos-repo "$DAIMOS_REPO" \
    --dofile "$build/system/boot/pdp6/boot.ini" \
    --pty-run "$work/pty-run" --login ROOT --probes "$work/reboot-probes.txt" \
    --work-dir "$work/reboot" --boot-timeout 45 --timeout 20
if ! grep -F 'HISTFILE TAIL REPAIRED' "$work/reboot/simh.log" >/dev/null; then
    echo 'HISTFILE repair notice missing from interactive login' >&2
    exit 1
fi
"$self/../../tools/daimos-simh-harness-v6.sh" \
    --daimos-repo "$DAIMOS_REPO" \
    --dofile "$build/system/boot/pdp6/boot.ini" \
    --pty-run "$work/pty-run" --login ROOT --probes "$work/repaired-probes.txt" \
    --work-dir "$work/repaired-reboot" --boot-timeout 45 --timeout 20
if grep -F 'HISTFILE TAIL REPAIRED' "$work/repaired-reboot/simh.log" >/dev/null; then
    echo 'HISTFILE repair repeated after successful truncation' >&2
    exit 1
fi
"$host_tools/d6fsck" -n 4 -d "$build/system/boot/pdp6/disk"
printf '%s\n' "$tag: PASS; artifacts in $work"
