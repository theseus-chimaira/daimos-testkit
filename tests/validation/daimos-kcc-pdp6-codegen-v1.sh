#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-kcc-pdp6-codegen-v1
work="$TMPDIR/$tag-$$"
build="$work/kernel"
asm="$build/kinit.s"

cleanup()
{
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$build"
PATH="$PDP10_PREFIX/bin:$PATH" \
    make -C "$DAIMOS_REPO/system/kernel" \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" "$asm" >/dev/null

if grep -E '^[[:space:]]*[Aa][Dd][Jj][Ss][Pp][[:space:]]' "$asm" >/dev/null 2>&1; then
        grep -n -E '^[[:space:]]*[Aa][Dd][Jj][Ss][Pp][[:space:]]' "$asm" >&2 || true
        echo "$tag: KCC emitted unsupported ADJSP for PDP-6 kernel target" >&2
        exit 1
fi

if ! grep -E '^[[:space:]]*(ADD|add|SUB|sub)[[:space:]]+17,\[[0-7]+,,[0-7]+\]' "$asm" >/dev/null 2>&1; then
        echo "$tag: expected PDP-6 simulated stack adjustment missing" >&2
        exit 1
fi

printf '%s\n' "$tag: PASS (PDP-6 KCC build contains only simulated stack adjustment)"
