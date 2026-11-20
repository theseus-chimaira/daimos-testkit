#!/bin/sh
# Verify GCC ABI and fail-stop behavior with a test-owned recording sink.
# This is not the DAIMOS guest syscall acceptance test.
set -eu
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
PDP10_TESTKIT_REPO=${PDP10_TESTKIT_REPO:-"$DAIMOS_REPO/../pdp10-testkit"}
P10RUN="$PDP10_PREFIX/bin/p10run"
PDP10_GCC="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-gcc-p10stdio-console-abi-v1.XXXXXXXX")
if [ "${P10_STDIO_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "recording-sink evidence: $work"
fi
libdir="$PDP10_PREFIX/lib/gcc-lib/pdp10-dec-none/3.2/freestanding"
for name in p10stdio-format-v2.s p10stdio-daimos-console-v1.s; do
    test -f "$libdir/$name" || {
        echo "missing installed GCC console ABI source: $name" >&2
        exit 2
    }
done
for name in libp10stdio-v2.a libp10stdio-daimos-v1.a; do
    test -s "$libdir/$name" || {
        echo "missing production GCC console archive: $name" >&2
        exit 2
    }
done

# Require actual DARC extraction and real cross-archive linking. The
# test-owned dsys_writechar sink records calls; this check explicitly
# does NOT exercise DAIMOS's monitor.
libgcc=$("$PDP10_GCC" -print-libgcc-file-name)
"$PDP10_GCC" -std=c89 -ffreestanding -fno-builtin -march=pdp6 \
    -O0 -S "$base/daimos-gcc-stdio-console-abi-v1.c" \
    -o "$work/console-client-v1.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/console-client-v1.dobj" \
    "$work/console-client-v1.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/crt0-v1.dobj" \
    "$PDP10_TESTKIT_REPO/support/crt0-upstream-v1.s"
"$PDP10_PREFIX/bin/dlink" -b 01000 \
    -M "$work/console-archive-v1.map" \
    -o "$work/console-archive-v1.dxr" \
    "$work/crt0-v1.dobj" "$work/console-client-v1.dobj" \
    "$libdir/libp10stdio-daimos-v1.a" "$libdir/libp10stdio-v2.a" \
    "$libgcc"
for symbol in printf vprintf putchar puts sprintf dsys_writechar \
              __p10stdio_vformat_v2; do
    grep -q "^$symbol[[:space:]]" "$work/console-archive-v1.map" || {
        echo "real console archive linkage missing: $symbol" >&2
        exit 1
    }
done
echo "PASS: GCC console production archive selection"

for machine in pdp6 ka10 ki10 ks10; do
    for profile in O0 O2; do
        echo "CHECK GCC console ABI $machine $profile"
        "$P10RUN" --machine "$machine" --mode deposit --exec-mode step \
            --step-limit 100000000 --timeout 25 \
            --workdir "$work/run-$machine-$profile" \
            --name "gcc-console-abi-$machine-$profile-v1" \
            --gcc-extra "-$profile" \
            --expect __test_exit=0 --expect fail_id=0 \
            "$PDP10_TESTKIT_REPO/support/crt0-upstream-v1.s" \
            "$base/daimos-gcc-stdio-console-abi-v1.c" \
            "$libdir/p10stdio-daimos-console-v1.s" \
            "$libdir/p10stdio-format-v2.s"
    done
done
echo "PASS GCC console stdarg/output error ABI: eight simulated CPUs/modes"
