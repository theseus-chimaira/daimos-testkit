#!/bin/sh
# Reproduce unresolved GCC/KCC qsort callback guest trap (must PASS once fixed).
# Current baseline (2026-11-23): guest reports UUO and STATUS:126.
# No compiler test-only I/O stubs or KCC varargs entry are linked.
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-gcc-kcc-qsort-v1829.XXXXXXXX")
passed=0
trap 'if [ "$passed" = 1 ] && [ "${KEEP_WORK:-0}" != 1 ]; then rm -rf "$work"; else echo "GCC/KCC callback guest diagnostics: $work" >&2; fi' EXIT HUP INT TERM
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
build="$work/build"
obj="$work/obj"
libc_build="$work/libc-build"
pty="$work/pty-run"
probes="$work/probes.txt"
dcs_port=$((23000 + ($$ % 7000)))
ge_port=$((43000 + ($$ % 7000)))
mkdir -p "$obj"
export PATH="$PDP10_PREFIX/bin:$PATH"
gcc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
stdio="$PDP10_PREFIX/lib/gcc-lib/pdp10-dec-none/3.2/freestanding"
libgcc=$("$gcc" -print-libgcc-file-name)

for file in "$stdio/libp10stdio-v2.a" \
            "$stdio/libp10stdio-daimos-v1.a" \
            "$PDP10_PREFIX/pdp10-dec-none/include/p10stdio-daimos-v1.h" \
            "$libgcc"; do
    test -f "$file" || { echo "missing real GCC stdio: $file" >&2; exit 2; }
done

make -C "$DAIMOS_REPO/userland/libc" build \
    CC="$PDP10_PREFIX/bin/kcc" BUILD_ROOT="$libc_build" \
    PDP10_PREFIX="$PDP10_PREFIX" >"$work/libc-build.log" 2>&1 || {
    tail -45 "$work/libc-build.log" >&2
    exit 1
}

"$gcc" -std=c89 -ffreestanding -fno-builtin -march=pdp6 \
    -O0 -I "$PDP10_PREFIX/pdp10-dec-none/include" \
    -S "$base/daimos-gcc-kcc-qsort-v1829.c" \
    -o "$obj/kcc-qsort-v1829.s"
for file in crt0 syscall; do
    "$das" -F -C -O "$obj/$file.dobj" \
        "$DAIMOS_REPO/userland/libc/$file.s"
done
"$das" -F -C -O "$obj/kcc-qsort-v1829.dobj" \
    "$obj/kcc-qsort-v1829.s"
"$dlink" --daimos-uuo-relax -b 020 \
    -o "$obj/gcc-kcc-qsort-v1829.dxr" \
    -M "$obj/gcc-kcc-qsort-v1829.map" \
    "$obj/crt0.dobj" "$obj/kcc-qsort-v1829.dobj" \
    "$stdio/libp10stdio-daimos-v1.a" \
    "$stdio/libp10stdio-v2.a" "$libc_build/libc/libc.a" "$libgcc"
# A GCC heap client cannot resolve malloc without the KCC libc archive.
# Reject accidental linkage through a compiler-owned or implicit libc.
if "$dlink" --daimos-uuo-relax -b 020 \
    -o "$obj/no-kcc-libc-v1829.dxr" \
    "$obj/crt0.dobj" "$obj/kcc-qsort-v1829.dobj" \
    "$stdio/libp10stdio-daimos-v1.a" \
    "$stdio/libp10stdio-v2.a" "$libgcc" \
    >"$work/no-kcc-libc-v1829.log" 2>&1; then
    echo 'unexpected GCC qsort link without KCC libc.a' >&2
    exit 1
fi

for symbol in qsort; do
    grep -q "^$symbol[[:space:]]" "$obj/gcc-kcc-qsort-v1829.map" || {
        echo "GCC/KCC qsort did not link real $symbol" >&2
        exit 1
    }
done

"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$pty" \
    "$base/../../tools/pty-run-v1.c"
cat >"$probes" <<'EOF_PROBES'
probe daimos-gcc-kcc-qsort-v1829
command /CONFIG/GCCQSORT; ECHO STATUS:$?
contains GCC-QSORT-V1829-PASS
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
    D6FS_EXTRA_ARGS="-f /CONFIG/GCCQSORT:$obj/gcc-kcc-qsort-v1829.dxr:555:dxr" \
    >"$work/guest-build.log" 2>&1 || {
    tail -55 "$work/guest-build.log" >&2
    exit 1
}

"$base/../../tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" \
    --dofile "$build/system/boot/pdp6/boot.ini" \
    --pty-run "$pty" --login ROOT --probes "$probes" \
    --work-dir "$work/run" --markdown-report "$work/report.md"
passed=1
echo "PASS: GCC callback into KCC qsort v1829"
