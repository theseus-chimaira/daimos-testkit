#!/bin/sh
# Verify GCC main argument registers and DAIMOS SIXBIT argv in a PDP-6 guest.
# No compiler test-only I/O stubs or KCC varargs entry are linked.
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-gcc-startup-argv-v1822.XXXXXXXX")
passed=0
trap 'if [ "$passed" = 1 ] && [ "${KEEP_WORK:-0}" != 1 ]; then rm -rf "$work"; else echo "GCC startup argv guest diagnostics: $work" >&2; fi' EXIT HUP INT TERM
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
    -S "$base/daimos-gcc-startup-argv-v1822.c" \
    -o "$obj/startup-argv-v1822.s"
for file in crt0 syscall; do
    "$das" -F -C -O "$obj/$file.dobj" \
        "$DAIMOS_REPO/userland/libc/$file.s"
done
"$das" -F -C -O "$obj/startup-argv-v1822.dobj" \
    "$obj/startup-argv-v1822.s"
"$dlink" --daimos-uuo-relax -b 020 \
    -o "$obj/gcc-startup-argv-v1822.dxr" \
    -M "$obj/gcc-startup-argv-v1822.map" \
    "$obj/crt0.dobj" "$obj/startup-argv-v1822.dobj" \
    "$stdio/libp10stdio-daimos-v1.a" \
    "$stdio/libp10stdio-v2.a" "$obj/syscall.dobj" "$libgcc"
for symbol in printf dsys_writechar; do
    grep -q "^$symbol[[:space:]]" "$obj/gcc-startup-argv-v1822.map" || {
        echo "GCC startup argv did not link real $symbol" >&2
        exit 1
    }
done

"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$pty" \
    "$base/../../tools/pty-run-v1.c"
cat >"$probes" <<'EOF_PROBES'
probe daimos-gcc-startup-argv-v1822
command /CONFIG/GCCARGV ARG1 ARG2; ECHO STATUS:$?
contains GCC-ARGV-V1822: 3 OK
contains GCC-ARGV-V1822-PASS
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
    D6FS_EXTRA_ARGS="-f /CONFIG/GCCARGV:$obj/gcc-startup-argv-v1822.dxr:555:dxr" \
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
echo "PASS: GCC DAIMOS main argc and SIXBIT argv v1822"
