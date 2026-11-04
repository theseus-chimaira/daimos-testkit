#!/bin/sh
# D16 acceptance matrix: exact-once release across independent fault guests.
# This is a full matrix, not a quick smoke test.  Do not treat a partial
# run as proof that D16 or the production OOM activation gate is closed.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$self/../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-oom-exact-once-v1146.XXXXXX")
printf 'v1146: acceptance logs: %s\n' "$work"

# D16 is a release gate.  Changing the kernel, fixtures or linker
# between guests would invalidate their combined acceptance record.
source_rev=$(git -C "$DAIMOS_REPO" rev-parse HEAD)
testkit_rev=$(git -C "$testkit" rev-parse HEAD)
tool_signature=$(cksum "$PDP10_PREFIX/bin/p10fold" \
    "$PDP10_PREFIX/bin/dlink" "$PDP10_PREFIX/bin/das" \
    "$PDP10_PREFIX/bin/pdp6")
printf 'DAIMOS %s\nTESTKIT %s\n%s\n' \
    "$source_rev" "$testkit_rev" "$tool_signature" > "$work/revisions.txt"
check_frozen_sources_v1146()
{
    test "$(git -C "$DAIMOS_REPO" rev-parse HEAD)" = "$source_rev" &&
    test "$(git -C "$testkit" rev-parse HEAD)" = "$testkit_rev" &&
    test -z "$(git -C "$DAIMOS_REPO" status --porcelain -- \
        system/kernel system/boot/pdp6)" &&
    test -z "$(git -C "$testkit" status --porcelain -- \
        tests/validation Makefile)" &&
    test "$(cksum "$PDP10_PREFIX/bin/p10fold" \
        "$PDP10_PREFIX/bin/dlink" "$PDP10_PREFIX/bin/das" \
        "$PDP10_PREFIX/bin/pdp6")" = "$tool_signature"
}
if ! check_frozen_sources_v1146; then
    echo 'v1146: candidate checkout or host tools are not frozen' >&2
    exit 1
fi

# Each selected guest verifies a different noninterchangeable resource
# ownership and retry invariant; running only v1144 is insufficient.
for target in \
    test-daimos-oom-transitive-release-v1087 \
    test-daimos-oom-pipe-dpy-vm-provider-v1144 \
    test-daimos-tty-vm-uarea-v1124 \
    test-daimos-session-hup-pipe-dpy-v1119 \
    test-daimos-session-hup-dpy-swap-v1121 \
    test-daimos-session-hup-pipe-swap-v1122 \
    test-daimos-fatal-exec-physical-uarea-v1142 \
    test-daimos-oom-pid-reuse-v1120 \
    test-daimos-oom-pid-reuse-enabled-v1120; do
    if ! check_frozen_sources_v1146; then
        echo 'v1146: source/tool revision changed during matrix' >&2
        exit 1
    fi
    printf 'v1146: RUN %s\n' "$target"
    if ! make --no-print-directory -C "$testkit" "$target" \
        DAIMOS_REPO="$DAIMOS_REPO" PDP10_PREFIX="$PDP10_PREFIX" \
        > "$work/$target.log" 2>&1; then
        printf 'v1146: FAIL %s; inspect %s\n' "$target" "$work/$target.log" >&2
        tail -60 "$work/$target.log" >&2
        exit 1
    fi
    if ! check_frozen_sources_v1146; then
        echo 'v1146: source/tool revision changed after guest' >&2
        exit 1
    fi
    printf 'v1146: PASS %s\n' "$target"
done

printf 'v1146: complete exact-once regression matrix PASS\n'
printf 'v1146: logs retained at %s\n' "$work"
