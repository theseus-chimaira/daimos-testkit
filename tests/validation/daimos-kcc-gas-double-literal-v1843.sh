#!/bin/sh
# KCC GAS dialect must emit DAS-acceptable single-line double literals.
# Historical multiline output made valid KI10/KS10 KCC code unassemblable.
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX required}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=${PDP10_TESTKIT_REPO:-"$base/../../../pdp10-testkit"}
kcc=${KCC_GUEST_COMPILER:-"$PDP10_PREFIX/bin/kcc"}
das=${DAS_BIN_V1843:-"$PDP10_PREFIX/bin/das"}
run="$PDP10_PREFIX/bin/p10run"
work=$(mktemp -d "$TMPDIR/kcc-gas-double-literal-v1843.XXXXXXXX")
trap 'if [ "${KEEP_WORK:-0}" = 1 ]; then echo "evidence: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
for machine in ki10 ks10; do
    for opt in off on; do
        case "$opt" in off) kopt= ;; on) kopt=-O ;; esac
        "$kcc" -Pgnu99 -x="$machine" -m=gas $kopt -I"$base" \
            -S "$base/daimos-kcc-gcc-float-struct-main-v1840.c" \
            -o "$work/float-main-$machine-$opt.s"
        grep -Ei 'dmove[[:space:]]+[^;]*\[[0-7]+,[0-7]+\]' \
            "$work/float-main-$machine-$opt.s" >/dev/null || {
            echo "KCC did not emit single-line double literal: $machine $opt" >&2
            exit 1
        }
        if grep -Ei 'dmove[[:space:]]+[^;]*\[[0-7]+[[:space:]]*$' \
                "$work/float-main-$machine-$opt.s" >/dev/null; then
            echo "KCC emitted multiline double literal: $machine $opt" >&2
            exit 1
        fi
        "$das" -F -C -O "$work/float-main-$machine-$opt.dobj" \
            "$work/float-main-$machine-$opt.s"
        "$kcc" -Pgnu99 -x="$machine" -m=gas $kopt \
            -S "$base/daimos-kcc-gas-double-literal-v1843.c" \
            -o "$work/guest-$machine-$opt.s"
        "$das" -F -C -O "$work/guest-$machine-$opt.dobj" \
            "$work/guest-$machine-$opt.s"
        "$run" --machine "$machine" --mode deposit --exec-mode step \
            --step-limit 100000 --timeout 20 \
            --workdir "$work/run-$machine-$opt" \
            --name "kcc-gas-double-literal-v1843-$machine-$opt" \
            --expect __test_exit=0 \
            "$root/support/crt0-upstream-v1.s" \
            "$work/guest-$machine-$opt.s" \
            "$root/support/exit-v1.s"
        echo "PASS KCC GAS double literals: $machine $opt"
    done
done
