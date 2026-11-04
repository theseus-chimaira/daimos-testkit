#!/bin/sh
# Distinct objects must not alias equal numeric LOCAL TEXT targets (v1141).
set -eu
: "${PDP10_PREFIX:?}" "${P10FOLD:?}" "${DLINK:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-p10fold-local-section-v1141.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

for n in a b; do
    case "$n" in
        a) distinct=2 ;;
        b) distinct=4 ;;
    esac
    cat > "$work/$n.s" <<EOF_ASM
        .text
        .globl ${n}_entry
${n}_entry:
        movei   2,1
        pushj   17,${n}_stage
        popj    17,
${n}_stage:
        setz    1,
        jrst    ${n}_end
        movei   2,$distinct
${n}_end:
        movei   3,3
        popj    17,
EOF_ASM
    "$PDP10_PREFIX/bin/das" -F -C -O "$work/$n.dobj" "$work/$n.s"
done

"$P10FOLD" -m 2 -P "$work/safe.fold" \
    "$work/a.dobj" "$work/b.dobj" > "$work/analysis"
if grep '^FOLD' "$work/safe.fold" >/dev/null; then
    echo 'v1141: distinct local targets incorrectly merged' >&2
    cat "$work/safe.fold" >&2
    exit 1
fi

# An injected, historically accepted invalid fold must also be rejected
# by the linker's independent fold-plan verifier.
printf 'P10FOLD1\nFOLD\t%s\t3\t%s\t3\t2\n' \
    "$work/b.dobj" "$work/a.dobj" > "$work/unsafe.fold"
if "$DLINK" -o "$work/invalid.dxr" --fold-plan "$work/unsafe.fold" \
    "$work/a.dobj" "$work/b.dobj" > "$work/link.log" 2>&1; then
    echo 'v1141: linker accepted cross-object LOCAL TEXT alias' >&2
    exit 1
fi
if ! grep -E 'stale or invalid fold plan range' "$work/link.log" >/dev/null; then
    cat "$work/link.log" >&2
    echo 'v1141: linker did not reject at the relocation verifier' >&2
    exit 1
fi
echo 'daimos-p10fold-local-section-v1141: PASS'
