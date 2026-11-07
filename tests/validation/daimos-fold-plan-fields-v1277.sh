#!/bin/sh
# Native host v1277: exact six-field fold-plan parsing for both tools.
# Invalid plans must fail before any fold or link is published.
set -eu
: "${PDP10_PREFIX:?}" "${P10FOLD:?}" "${DLINK:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-fold-plan-fields-v1277.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

for obj in a b; do
    cat > "$work/$obj.s" <<EOF_ASM
        .text
        .globl ${obj}_entry
${obj}_entry:
        movei   1,1
        popj    17,
EOF_ASM
    "$PDP10_PREFIX/bin/das" -F -C -O "$work/$obj.dobj" \
        "$work/$obj.s"
done

printf 'P10FOLD1\n' > "$work/valid.fold"
"$DLINK" -o "$work/valid.dxr" --fold-plan "$work/valid.fold" \
    "$work/a.dobj" "$work/b.dobj" > "$work/valid-link.log" 2>&1
"$P10FOLD" -m 2 -a "$work/a.dobj" -x "$work/valid.fold" \
    "$work/b.dobj" > "$work/valid-fold.log" 2>&1

check_bad()
{
    label=$1
    line=$2
    printf 'P10FOLD1\n%s\n' "$line" > "$work/$label.fold"
    if "$DLINK" -o "$work/$label.dxr" --fold-plan \
        "$work/$label.fold" "$work/a.dobj" "$work/b.dobj" \
        > "$work/$label.link.log" 2>&1; then
        echo "v1277: dlink accepted invalid $label" >&2
        exit 1
    fi
    if ! grep -q 'malformed fold plan line' \
        "$work/$label.link.log"; then
        echo "v1277: unexpected linker failure for $label" >&2
        cat "$work/$label.link.log" >&2
        exit 1
    fi
    if "$P10FOLD" -m 2 -a "$work/a.dobj" -x \
        "$work/$label.fold" "$work/b.dobj" \
        > "$work/$label.fold.log" 2>&1; then
        echo "v1277: p10fold accepted invalid $label" >&2
        exit 1
    fi
    if ! grep -q 'malformed anchor fold-plan line' \
        "$work/$label.fold.log"; then
        echo "v1277: unexpected folder failure for $label" >&2
        cat "$work/$label.fold.log" >&2
        exit 1
    fi
}

# Numeric values are octal. The path fields must be nonempty, and no
# extra tab-separated column may be silently discarded.
check_bad empty-donor "$(printf 'FOLD\t\t1\t%s\t1\t2' "$work/a.dobj")"
check_bad empty-offset "$(printf 'FOLD\t%s\t\t%s\t1\t2' \
    "$work/b.dobj" "$work/a.dobj")"
check_bad empty-anchor "$(printf 'FOLD\t%s\t1\t\t1\t2' \
    "$work/b.dobj")"
check_bad empty-words "$(printf 'FOLD\t%s\t1\t%s\t1\t' \
    "$work/b.dobj" "$work/a.dobj")"
check_bad missing-field "$(printf 'FOLD\t%s\t1\t%s\t1' \
    "$work/b.dobj" "$work/a.dobj")"
check_bad extra-field "$(printf 'FOLD\t%s\t1\t%s\t1\t2\tX' \
    "$work/b.dobj" "$work/a.dobj")"
check_bad trailing-tab "$(printf 'FOLD\t%s\t1\t%s\t1\t2\t' \
    "$work/b.dobj" "$work/a.dobj")"

echo 'v1277: valid empty plan and seven malformed six-field plans PASS'
