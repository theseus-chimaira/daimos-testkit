#!/bin/sh
# Verify GCC variadic calls into KCC-built printf/sprintf on PDP-6 DAIMOS.
# No compiler test-only I/O stubs or KCC varargs entry are linked.
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-gcc-kcc-varargs-libc-v1838.XXXXXXXX")
passed=0
trap 'if [ "$passed" = 1 ] && [ "${KEEP_WORK:-0}" != 1 ]; then rm -rf "$work"; else echo "GCC/KCC libc varargs guest diagnostics: $work" >&2; fi' EXIT HUP INT TERM
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
libgcc=$("$gcc" -print-libgcc-file-name)

make -C "$DAIMOS_REPO/userland/libc" build \
    CC="$PDP10_PREFIX/bin/kcc" BUILD_ROOT="$libc_build" \
    PDP10_PREFIX="$PDP10_PREFIX" >"$work/libc-build.log" 2>&1 || {
    tail -45 "$work/libc-build.log" >&2
    exit 1
}

for file in crt0 syscall; do
    "$das" -F -C -O "$obj/$file.dobj" \
        "$DAIMOS_REPO/userland/libc/$file.s"
done

for opt in 0 2; do
    "$gcc" -std=c89 -ffreestanding -fno-builtin -march=pdp6 \
        -O"$opt" -I "$PDP10_PREFIX/pdp10-dec-none/include" \
        -S "$base/daimos-gcc-kcc-varargs-libc-v1838.c" \
        -o "$obj/kcc-varargs-libc-v1838-$opt.s"
    "$das" -F -C -O "$obj/kcc-varargs-libc-v1838-$opt.dobj" \
        "$obj/kcc-varargs-libc-v1838-$opt.s"
    "$dlink" --daimos-uuo-relax -b 020 \
        -o "$obj/gcc-kcc-varargs-libc-v1838-$opt.dxr" \
        -M "$obj/gcc-kcc-varargs-libc-v1838-$opt.map" \
        "$obj/crt0.dobj" "$obj/kcc-varargs-libc-v1838-$opt.dobj" \
        "$libc_build/libc/libc.a" "$libgcc"

    # DLINK may relax WRITECHAR into a UUO and remove its veneer symbol.
    # Require the production KCC formatter and assembly sprintf members.
    for symbol in printf vprintf sprintf vsprintf __daimos_fround0_v33; do
        grep -q "^$symbol[[:space:]]" \
            "$obj/gcc-kcc-varargs-libc-v1838-$opt.map" || {
            echo "GCC/KCC varargs did not link real $symbol at -O$opt" >&2
            exit 1
        }
    done
done
# GCC must not acquire an implicit printf/sprintf without KCC libc.a.
# This negative control forbids silent replacement by GCC-native stdio.
if "$dlink" --daimos-uuo-relax -b 020 \
    -o "$obj/no-kcc-libc-v1838.dxr" \
    "$obj/crt0.dobj" "$obj/kcc-varargs-libc-v1838-0.dobj" \
    "$libgcc" \
    >"$work/no-kcc-libc-v1838.log" 2>&1; then
    echo 'unexpected GCC stdio link without KCC libc.a' >&2
    exit 1
fi

"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$pty" \
    "$base/../../tools/pty-run-v1.c"
cat >"$probes" <<'EOF_PROBES'
probe daimos-gcc-kcc-varargs-libc-v1838-o0
command /CONFIG/GCCVAR0; ECHO STATUS:$?
contains KCC-VARARGS-V1838: 23 OK 172
contains STATUS:0
end
probe daimos-gcc-kcc-varargs-libc-v1838-o2
command /CONFIG/GCCVAR2; ECHO STATUS:$?
contains KCC-VARARGS-V1838: 23 OK 172
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
    D6FS_EXTRA_ARGS="-f /CONFIG/GCCVAR0:$obj/gcc-kcc-varargs-libc-v1838-0.dxr:555:dxr -f /CONFIG/GCCVAR2:$obj/gcc-kcc-varargs-libc-v1838-2.dxr:555:dxr" \
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
echo "PASS: GCC caller KCC libc printf and sprintf v1838"
