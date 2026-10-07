#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-d6fs-large-incremental-write-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
obj="$work/obj"
pty="$work/pty-run"
probes="$work/probes.txt"
dcs_port=$((23000 + ($$ % 7000)))
ge_port=$((43000 + ($$ % 7000)))
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
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
"$cc" -std=c99 -Os $incs -S "$DAIMOS_REPO/userland/libc/u.c" -o "$obj/u.s"
"$das" -F -C -O "$obj/u.dobj" "$obj/u.s"
"$cc" -std=c99 -Os $incs -S "$self/daimos-d6fs-large-incremental-write-v1.c" -o "$obj/test.s"
"$das" -F -C -O "$obj/test.dobj" "$obj/test.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$obj/test.dxr" -M "$obj/test.map" \
        "$obj/crt0.dobj" "$obj/syscall.dobj" "$obj/u.dobj" \
        "$obj/test.dobj" "$libgcc"

cc_host=${HOST_CC:-cc}
"$cc_host" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$self/../../tools/pty-run-v1.c"
cat >"$probes" <<'PROBES'
probe d6fs-large-incremental-write
command /CONFIG/D6GROW.TEST; ECHO STATUS:$?
contains D6FS-LARGE-INCREMENTAL-PASS
contains STATUS:0
end
PROBES

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
        SIMH_CPU_KWORDS="${SIMH_CPU_KWORDS:-96}" \
        SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" \
        D6FS_EXTRA_ARGS="-f /CONFIG/D6GROW.TEST:$obj/test.dxr:555:dxr" >/dev/null

"$self/../../tools/daimos-simh-harness-v4.sh" \
        --daimos-repo "$DAIMOS_REPO" \
        --dofile "$build/system/boot/pdp6/boot.ini" \
        --pty-run "$pty" --login ROOT --probes "$probes" \
        --timeout 180 --boot-timeout 90 \
        --work-dir "$work/run" --markdown-report "$work/report.md"

printf '%s\n' "$tag: PASS (3000 one-word D6FS appends across 2048-word boundary)"
