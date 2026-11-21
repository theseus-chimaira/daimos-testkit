#!/bin/sh
# Verify the real KCC DSH build and its 036000-octal EXEC image limit.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"
work="$TMPDIR/daimos-dsh-kcc-image-v1735-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
make -C "$DAIMOS_REPO/userland" "$work/userland/dsh.dxr" \
    COMPILER=kcc KCC="${KCC_V1735_OVERRIDE:-kcc}" \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD_ROOT="$work" \
    > "$work/build.log" 2>&1 || {
        tail -30 "$work/build.log" >&2
        exit 1
    }
grep -q '^p10fold -m 2 ' "$work/build.log" || {
    echo 'DSH did not use two-word fold floor' >&2
    exit 1
}
report=$(dxrcheck "$work/userland/dsh.dxr")
image=$(printf '%s\n' "$report" | sed -n 's/^DXR image=\([0-7][0-7]*\).*/\1/p')
bss=$(printf '%s\n' "$report" | sed -n 's/^.* bss=\([0-7][0-7]*\).*/\1/p')
test -n "$image" && test -n "$bss"
test "$((0$image))" -le "$((036000))" || {
    echo "DSH image $image exceeds 036000" >&2
    exit 1
}
test "$((0$bss))" -le "$((001763))" || {
    echo "DSH BSS $bss exceeds 001763" >&2
    exit 1
}
echo "DSH KCC v1735: image=$image bss=$bss fold=2 PASS"
