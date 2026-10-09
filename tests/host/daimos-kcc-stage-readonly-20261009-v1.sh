#!/bin/sh
# Re-staging read-only installed KCC bootstrap inputs must be repeatable.
set -eu
: "${DAIMOS_REPO:?}"
: "${KCC_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"
work=$(mktemp -d "$TMPDIR/daimos-kcc-stage-readonly-20261009-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
stage() {
    sh "$DAIMOS_REPO/scripts/stage-kcc-sources-v1.sh" \
        "$KCC_REPO" "$work/staged" "$PDP10_PREFIX/bin/csix" \
        "$PDP10_PREFIX/bin/s6text" "$DAIMOS_REPO" \
        "$PDP10_PREFIX/lib/kcc/bootstrap"
}
stage
for n in CRT0.DOBJ BOOT.DOBJ SYS.DOBJ HELP.DOBJ LIBC.DARC; do
    chmod 0444 "$work/staged/BOOT/$n"
done
stage
stage
for n in CRT0.DOBJ BOOT.DOBJ SYS.DOBJ HELP.DOBJ LIBC.DARC; do
    test -w "$work/staged/BOOT/$n"
    test -s "$work/staged/BOOT/$n"
done
printf '%s\n' 'PASS: KCC source stage replaces read-only previous artifacts'
