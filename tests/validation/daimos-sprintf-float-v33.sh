#!/bin/sh
# Native DAIMOS allocator/output and original hosted regression sources.
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export TMPDIR
PDP10_TESTKIT_REPO=${PDP10_TESTKIT_REPO:-"$DAIMOS_REPO/../pdp10-testkit"}
tag=daimos-sprintf-float-v33
work="$TMPDIR/$tag-$$"
build="$work/build"
obj="$work/obj"
libc_build="$work/libc-build"
pty="$work/pty-run"
probes="$work/probes.txt"
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
dcs_port=$((23000 + ($$ % 7000)))
ge_port=$((43000 + ($$ % 7000)))

cleanup() {
        if [ "${KEEP_WORK:-0}" = 1 ]; then
                printf '%s\n' "$tag: work preserved at $work" >&2
        else
                rm -rf "$work"
        fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$obj"
export PATH="$PDP10_PREFIX/bin:$PATH"
kcc="$PDP10_PREFIX/bin/kcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"

make -C "$DAIMOS_REPO/userland/libc" build \
        CC="$kcc" BUILD_ROOT="$libc_build" \
        PDP10_PREFIX="$PDP10_PREFIX" >"$work/libc-build.log" 2>&1

incs="-I$DAIMOS_REPO/userland/libc -I$PDP10_PREFIX/lib/kcc/include"
incs="$incs -I$DAIMOS_REPO/system/kernel/core"
incs="$incs -I$DAIMOS_REPO/system/kernel/fs"
incs="$incs -I$DAIMOS_REPO/system/kernel/proc"
incs="$incs -I$DAIMOS_REPO/system/kernel/storage"
incs="$incs -I$PDP10_PREFIX/include"

"$das" -F -C -O "$obj/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$obj/syscall-helpers.dobj" \
        "$DAIMOS_REPO/userland/libc/syscall_helpers.s"

build_guest() {
        source_file=$1
        stem=$2
        "$kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs -S \
                "$source_file" -o "$obj/$stem.s" >"$obj/$stem-compile.log" 2>&1
        "$das" -F -C -O "$obj/$stem.dobj" "$obj/$stem.s"
        "$dlink" --daimos-uuo-relax -b 020 -o "$obj/$stem.dxr" \
                -M "$obj/$stem.map" \
                "$obj/crt0.dobj" "$obj/syscall-helpers.dobj" \
                "$libc_build/libc/syscall.dobj" \
                "$libc_build/libc/stdlib.dobj" \
                "$libc_build/libc/printf.dobj" \
        "$libc_build/libc/sprintf-v33.dobj" \
        "$libc_build/libc/dformat-f0-v33.dobj" \
                "$libc_build/libc/process_ctype.dobj" \
                "$libc_build/libc/memset-v1.dobj" \
        "$libc_build/libc/memcpy.dobj" \
        "$libc_build/libc/strlen-v1.dobj" \
        "$libc_build/libc/strcmp-v1.dobj" \
                "$libc_build/libc/string.dobj" \
                "$obj/$stem.dobj"
}

build_guest "$base/daimos-sprintf-float-v33.c" float-v33
build_guest "$PDP10_TESTKIT_REPO/tests/todo/generic/930513-1.c" orig-float-v33

"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$base/../../tools/pty-run-v1.c"
cat >"$probes" <<'EOF_PROBES'
probe daimos-sprintf-float-rounding-v33
command /CONFIG/FLOATV33; ECHO STATUS:$?
contains DAIMOS-SPRINTF-FLOAT-V33-PASS
contains STATUS:0
end
probe original-930513-1-v33
command /CONFIG/ORIGFLOATV33; ECHO STATUS:$?
contains STATUS:0
end
EOF_PROBES

make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
        DAS_REPO="${DAS_REPO:-$DAIMOS_REPO/../das}" \
        DAIMOS_TOOLS_REPO="${DAIMOS_TOOLS_REPO:-$DAIMOS_REPO/../daimos-tools}" \
        KCC_REPO="${KCC_REPO:-$DAIMOS_REPO/../kcc}" \
        SIMH_CPU_KWORDS="${SIMH_CPU_KWORDS:-256}" \
        SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" \
        D6FS_EXTRA_ARGS="-f /CONFIG/FLOATV33:$obj/float-v33.dxr:555:dxr -f /CONFIG/ORIGFLOATV33:$obj/orig-float-v33.dxr:555:dxr" \
        >"$work/guest-build.log" 2>&1

"$base/../../tools/daimos-simh-harness-v4.sh" \
        --daimos-repo "$DAIMOS_REPO" \
        --dofile "$build/system/boot/pdp6/boot.ini" \
        --pty-run "$pty" --login ROOT --probes "$probes" \
        --work-dir "$work/run" --markdown-report "$work/report.md"

printf '%s\n' "$tag: PASS (assembler sprintf float, original 930513-1.c)"
