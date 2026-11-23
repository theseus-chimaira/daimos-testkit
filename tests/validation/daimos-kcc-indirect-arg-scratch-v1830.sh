#!/bin/sh
# Validate PDP-6 KCC indirect-call targets across AC16-using arguments.
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX required}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=${PDP10_TESTKIT_REPO:-"$base/../../../pdp10-testkit"}
cc=${KCC_GUEST_COMPILER:-"$PDP10_PREFIX/bin/kcc"}
run="$PDP10_PREFIX/bin/p10run"
work=$(mktemp -d "$TMPDIR/kcc-indirect-arg-scratch-v1830.XXXXXXXX")
trap 'if [ "${KEEP_WORK:-0}" = 1 ]; then echo "evidence: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
for opt in off on; do
    case "$opt" in
        off) flags= ;;
        on) flags=-O ;;
    esac
    "$cc" -Pgnu99 -x=pdp6 -m=gas $flags -S \
        "$base/daimos-kcc-indirect-arg-scratch-v1830.c" \
        -o "$work/client-$opt.s"
    for machine in pdp6 ka10 ki10 ks10; do
        "$run" --machine "$machine" --mode deposit --exec-mode step \
            --step-limit 100000 --timeout 18 \
            --workdir "$work/run-$machine-$opt" \
            --name "kcc-indirect-arg-scratch-v1830-$machine-$opt" \
            --expect __test_exit=0 --expect fail_id_v1830=0 \
            "$root/support/crt0-upstream-v1.s" \
            "$work/client-$opt.s" \
            "$root/support/exit-v1.s" "$root/support/abort-v1.s"
        echo "PASS: KCC indirect call $machine $opt"
    done
done
