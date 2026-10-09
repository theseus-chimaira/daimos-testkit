#!/bin/sh
# Behavioral coverage for the full-block D6FS append/extent-grow path.
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-d6fs-extent-growth-20261009-v1
work="$TMPDIR/$tag-$$"
obj="$work/obj"
build="$work/build/system/boot/pdp6"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
dcs_port=$((23000 + ($$ % 7000)))
ge_port=$((43000 + ($$ % 7000)))
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
"$cc" -std=c99 -Os $incs -S "$self/$tag.c" -o "$obj/test.s"
"$das" -F -C -O "$obj/test.dobj" "$obj/test.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$obj/test.dxr" -M "$obj/test.map" \
        "$obj/crt0.dobj" "$obj/syscall.dobj" "$obj/u.dobj" \
        "$obj/test.dobj" "$libgcc"

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$work/pty" \
        "$self/../../tools/pty-run-v1.c"
cat > "$work/probes" <<'PROBES'
probe d6fs-extent-growth
command /CONFIG/D6EXTEND.TEST; ECHO STATUS:$?
contains D6FS-EXTENT-GROWTH-PASS
contains STATUS:0
end
PROBES

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
        SIMH_CPU_KWORDS="${SIMH_CPU_KWORDS:-96}" \
        SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" \
        D6FS_EXTRA_ARGS="-f /CONFIG/D6EXTEND.TEST:$obj/test.dxr:555:dxr" >/dev/null

"$self/../../tools/daimos-simh-harness-v4.sh" \
        --daimos-repo "$DAIMOS_REPO" --dofile "$build/boot.ini" \
        --pty-run "$work/pty" --login ROOT --probes "$work/probes" \
        --timeout 180 --boot-timeout 90 \
        --work-dir "$work/run" --markdown-report "$work/report.md"
echo "$tag: PASS (12288 words, 96 block writes, readback across seven-reserve boundary)"
