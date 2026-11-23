#!/bin/sh
# PDP-10 GCC BLT source/destination word-address correctness.
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX required}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=${PDP10_TESTKIT_REPO:-"$base/../../../pdp10-testkit"}
gcc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
p10run="$PDP10_PREFIX/bin/p10run"
if [ -n "${PDP10_CC1_DIR_V1837:-}" ]; then
    gcc_extra="-B${PDP10_CC1_DIR_V1837}/"
else
    gcc_extra=
fi
work=$(mktemp -d "$TMPDIR/gcc-blt-word-frame-v1837.XXXXXXXX")
trap 'if [ "${KEEP_WORK:-0}" = 1 ]; then echo "evidence: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
for cpu in ${ABI_CPUS_V1837:-pdp6 ka10 ki10 ks10}; do
    for opt in ${ABI_OPTS_V1837:-0 1 2 s}; do
        "$gcc" $gcc_extra -std=c89 -ffreestanding -fno-builtin \
            -march="$cpu" -O"$opt" -S \
            "$base/daimos-gcc-blt-word-frame-v1837.c" \
            -o "$work/client-$cpu-$opt.s"
        "$p10run" --machine "$cpu" --mode deposit --exec-mode step \
            --step-limit 250000 --timeout 20 \
            --workdir "$work/run-$cpu-$opt" \
            --name "gcc-blt-word-frame-v1837-$cpu-$opt" \
            --expect __test_exit=0 --expect fail_v1837=0 \
            "$root/support/crt0-upstream-v1.s" \
            "$work/client-$cpu-$opt.s" \
            "$root/support/exit-v1.s" "$root/support/abort-v1.s"
        echo "PASS: GCC word-frame BLT $cpu -O$opt"
    done
done
