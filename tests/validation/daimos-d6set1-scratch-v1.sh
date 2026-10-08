#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
DAS_REPO=${DAS_REPO:-$HOME/git/das}
DAIMOS_TOOLS_REPO=${DAIMOS_TOOLS_REPO:-$HOME/git/daimos-tools}
KCC_REPO=${KCC_REPO:-$HOME/git/kcc}
tag=daimos-d6set1-scratch-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
obj="$work/obj"
pty="$work/pty-run"
probes="$work/probes.txt"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
trap 'rm -rf "$work"' EXIT HUP INT TERM
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
"$das" -F -C -O "$obj/memcpy.dobj" "$DAIMOS_REPO/userland/libc/memcpy.s"
"$cc" -std=c99 -Os $incs -S "$DAIMOS_REPO/userland/libc/u.c" -o "$obj/u.s"
"$das" -F -C -O "$obj/u.dobj" "$obj/u.s"
"$cc" -std=c99 -Os $incs -S "$DAIMOS_REPO/userland/libc/stdlib.c" -o "$obj/stdlib.s"
"$das" -F -C -O "$obj/stdlib.dobj" "$obj/stdlib.s"
"$cc" -std=c99 -Os $incs -S "$DAIMOS_REPO/userland/libc/string.c" -o "$obj/string.s"
"$das" -F -C -O "$obj/string.dobj" "$obj/string.s"
"$cc" -std=c99 -Os $incs -S "$self/daimos-d6set1-scratch-v1.c" -o "$obj/test.s"
"$das" -F -C -O "$obj/test.dobj" "$obj/test.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$obj/test.dxr" -M "$obj/test.map" \
        "$obj/crt0.dobj" "$obj/syscall.dobj" "$obj/memcpy.dobj" "$obj/u.dobj" \
        "$obj/stdlib.dobj" "$obj/string.dobj" "$obj/test.dobj" "$libgcc"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -o "$pty" "$self/../../tools/pty-run-v1.c"
cat >"$probes" <<'PROBES'
probe d6set1-mount
command MOUNTS
contains D6FS /SCRATCH
end
probe d6set1-scratch
command /CONFIG/D6SET1.TEST
contains D6SET1-SCRATCH-PASS
end
PROBES
PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
        SIMH_CPU_KWORDS=96 DAS_REPO="$DAS_REPO" \
        DAIMOS_TOOLS_REPO="$DAIMOS_TOOLS_REPO" KCC_REPO="$KCC_REPO" \
        D6FS_EXTRA_ARGS="-f /CONFIG/D6SET1.TEST:$obj/test.dxr:555:dxr" >/dev/null
"$self/../../tools/daimos-simh-harness-v4.sh" --daimos-repo "$DAIMOS_REPO" \
        --dofile "$build/system/boot/pdp6/boot.ini" --pty-run "$pty" \
        --login ROOT --probes "$probes" --timeout 120 --boot-timeout 90 \
        --work-dir "$work/run" --markdown-report "$work/report.md"
printf '%s\n' "$tag: PASS (RW D6SET1 mount, two block writes/readback, cleanup)"
