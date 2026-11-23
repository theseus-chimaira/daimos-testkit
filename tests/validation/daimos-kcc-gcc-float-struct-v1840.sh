#!/bin/sh
# Test both GCC/KCC directions of the float/double-containing aggregate return ABI.
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX required}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=${PDP10_TESTKIT_REPO:-"$base/../../../pdp10-testkit"}
kcc=${KCC_GUEST_COMPILER:-"$PDP10_PREFIX/bin/kcc"}
gcc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
p10run="$PDP10_PREFIX/bin/p10run"
# Test an uninstalled rebuilt backend without replacing the installed cc1.
if [ -n "${PDP10_CC1_DIR_V1840:-}" ]; then
    gcc_extra="-B${PDP10_CC1_DIR_V1840}/"
else
    gcc_extra=
fi
work=$(mktemp -d "$TMPDIR/kcc-gcc-float-struct-v1840.XXXXXXXX")
trap 'if [ "${KEEP_WORK:-0}" = 1 ]; then echo "evidence: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
for machine in ${ABI_CPUS_V1840:-pdp6 ka10 ki10 ks10}; do
    for opt in ${ABI_OPTS_V1840:-0 1 2 s}; do
        for role in main callee; do
            source="$base/daimos-kcc-gcc-float-struct-$role-v1840.c"
            "$gcc" $gcc_extra -std=c89 -ffreestanding -fno-builtin -march="$machine" \
                -O"$opt" -I"$base" -S "$source" \
                -o "$work/gcc-$role-$machine-$opt.s"
            case "$opt" in
                0) kopt= ;;
                1|2|s) kopt=-O ;;
                *) echo "unsupported optimization: $opt" >&2; exit 2 ;;
            esac
            "$kcc" -Pgnu99 -x="$machine" -m=gas $kopt -I"$base" \
                -S "$source" -o "$work/kcc-$role-$machine-$opt.s"
        done
        for direction in gcc-kcc kcc-gcc; do
            case "$direction" in
                gcc-kcc) caller=gcc; callee=kcc ;;
                kcc-gcc) caller=kcc; callee=gcc ;;
            esac
            "$p10run" --machine "$machine" --mode deposit \
                --exec-mode step --step-limit 300000 --timeout 20 \
                --workdir "$work/run-$direction-$machine-$opt" \
                --name "float-struct-$direction-$machine-$opt-v1840" \
                --expect __test_exit=0 --expect fail_v1840=0 \
                "$root/support/crt0-upstream-v1.s" \
                "$work/$caller-main-$machine-$opt.s" \
                "$work/$callee-callee-$machine-$opt.s" \
                "$root/support/exit-v1.s" "$root/support/abort-v1.s"
            echo "PASS: floating struct return $direction $machine -O$opt"
        done
    done
done
