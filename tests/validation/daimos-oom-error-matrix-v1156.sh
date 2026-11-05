#!/bin/sh
# E09: independent physical-MM and DISK error-class acceptance.
# No production OOM enablement; positive tests change only copied kernels.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$self/../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-oom-error-matrix-v1156.XXXXXX")
printf 'v1156: retaining error-class matrix logs at %s\n' "$work"

# Identical candidate and tools across every separate guest.
daimos_rev=$(git -C "$DAIMOS_REPO" rev-parse HEAD)
testkit_rev=$(git -C "$testkit" rev-parse HEAD)
tool_sig=$(cksum "$PDP10_PREFIX/bin/p10fold" \
    "$PDP10_PREFIX/bin/dlink" "$PDP10_PREFIX/bin/das" \
    "$PDP10_PREFIX/bin/pdp6")
printf 'DAIMOS %s\nTESTKIT %s\n%s\n' \
    "$daimos_rev" "$testkit_rev" "$tool_sig" > "$work/revisions.txt"
check_frozen_v1156()
{
    test "$(git -C "$DAIMOS_REPO" rev-parse HEAD)" = "$daimos_rev" &&
    test "$(git -C "$testkit" rev-parse HEAD)" = "$testkit_rev" &&
    test -z "$(git -C "$DAIMOS_REPO" status --porcelain -- \
        system/kernel system/boot/pdp6)" &&
    test -z "$(git -C "$testkit" status --porcelain -- \
        tests/validation Makefile)" &&
    test "$(cksum "$PDP10_PREFIX/bin/p10fold" \
        "$PDP10_PREFIX/bin/dlink" "$PDP10_PREFIX/bin/das" \
        "$PDP10_PREFIX/bin/pdp6")" = "$tool_sig"
}
if ! check_frozen_v1156; then
    echo 'v1156: source/tool candidate is not frozen' >&2
    exit 1
fi

printf 'v1156: RUN source contract\n'
if ! DAIMOS_REPO="$DAIMOS_REPO" \
    python3 "$self/daimos-oom-brk-classification-v998.py" \
    > "$work/source-classification.log" 2>&1; then
    cat "$work/source-classification.log" >&2
    exit 1
fi

# These complementary guests must remain independent: a full DISK
# bitmap is not a fragmentation failure, descriptor exhaustion or
# physical OOM. Actual owner/bitmap cleanup is checked at each gate.
for target in \
    test-daimos-mm-exhaustion-class-v1111 \
    test-daimos-oom-backstore-capacity-v1156 \
    test-daimos-oom-disk-full-v1156 \
    test-daimos-oom-disk-full-enabled-v1156 \
    test-daimos-oom-mm-fragment-enabled-v1115 \
    test-daimos-oom-mm-slots-enabled-v1114 \
    test-daimos-oom-brk-negatives-enabled-v1110 \
    test-daimos-fatal-mm-wrong-owner-v1101 \
    test-daimos-oom-physical-vm-v1106; do
    if ! check_frozen_v1156; then
        echo "v1156: source/tool revision changed before $target" >&2
        exit 1
    fi
    printf 'v1156: RUN %s\n' "$target"
    if ! make --no-print-directory -C "$testkit" "$target" \
        DAIMOS_REPO="$DAIMOS_REPO" PDP10_PREFIX="$PDP10_PREFIX" \
        > "$work/$target.log" 2>&1; then
        printf 'v1156: FAIL %s; inspect %s\n' \
            "$target" "$work/$target.log" >&2
        tail -70 "$work/$target.log" >&2
        exit 1
    fi
    if ! check_frozen_v1156; then
        echo "v1156: source/tool revision changed after $target" >&2
        exit 1
    fi
    printf 'v1156: PASS %s\n' "$target"
done
printf 'v1156: E09 complete real-MM and backing-class matrix PASS\n'
printf 'v1156: logs retained at %s\n' "$work"
