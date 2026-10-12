#!/bin/sh
# Keep PDP-10 skip-controlled transfers distinct when their successors differ.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"

work="$TMPDIR/daimos-p10fold-io-skip-20261012-v1-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

make -C "$DAIMOS_REPO/tools/host" \
    "$work/tools/host/p10fold" BUILD_ROOT="$work" \
    PDP10_PREFIX="$PDP10_PREFIX" >/dev/null
fold="$work/tools/host/p10fold"
assembler="$PDP10_PREFIX/bin/das"

# Both loops have the same instruction pair, but different fall-throughs.
# Their first instruction can skip the apparent terminating JRST, so neither
# loop is a removable zero-cost duplicate. Include the I/O count-overflow
# skips, status skips, and indirect execute, all of which can skip a word.
for variant in blki blko consz conso xct; do
    case "$variant" in
        blki) instruction='blki 0300,0' ;;
        blko) instruction='blko 0300,0' ;;
        consz) instruction='consz 0750,00100' ;;
        conso) instruction='conso 0750,00100' ;;
        xct) instruction='xct 1' ;;
    esac
    cat > "$work/$variant.s" <<EOF_ASM
        .text
        .globl entry
entry:
        $instruction
        jrst entry
        movei 1,7
        popj 17,
        $instruction
        jrst .-1
        movei 1,6
        popj 17,
EOF_ASM
    "$assembler" -F -C -O "$work/$variant.dobj" "$work/$variant.s"
    "$fold" -m 2 -P "$work/$variant.fold" "$work/$variant.dobj" \
        > "$work/$variant.analysis"
    if grep '^FOLD' "$work/$variant.fold" >/dev/null; then
        echo "p10fold wrongly folded $variant skip/JRST prefixes" >&2
        cat "$work/$variant.fold" >&2
        exit 1
    fi
done

# Control: a genuine terminating, non-skipping pair remains foldable.
cat > "$work/control.s" <<'EOF_ASM'
        .text
        .globl entry
entry:
        movei 1,3
        jrst entry
        movei 1,7
        popj 17,
        movei 1,3
        jrst .-1
        movei 1,6
        popj 17,
EOF_ASM
"$assembler" -F -C -O "$work/control.dobj" "$work/control.s"
"$fold" -m 2 -P "$work/control.fold" "$work/control.dobj" \
    > "$work/control.analysis"
grep '^FOLD' "$work/control.fold" >/dev/null || {
    echo 'p10fold rejected the safe non-skipping control' >&2
    exit 1
}

echo 'daimos-p10fold-io-skip-20261012-v1: PASS'
