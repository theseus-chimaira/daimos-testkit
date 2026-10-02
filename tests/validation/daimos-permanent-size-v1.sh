#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
resident_limit=${DAIMOS_RESIDENT_WORDS_MAX:-}
last_limit=${DAIMOS_PERMANENT_LAST_MAX:-16383}
work="$TMPDIR/daimos-permanent-size-v1-$$"
out="$work/permanent-size.out"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
make -C "$DAIMOS_REPO/system/boot/pdp6" permanent-size \
    BUILD_ROOT="$work/build" PDP10_PREFIX="$PDP10_PREFIX" >"$out" 2>&1
resident=$(awk '$1 == "KCORE+MRES" { print $3; exit }' "$out")
last=$(awk '$1 == "PERMANENT_LAST" { print $3; exit }' "$out")
case "$resident" in
''|*[!0-9]*) cat "$out" >&2; echo 'permanent-size: could not parse resident word count' >&2; exit 1;;
esac
case "$last" in
''|*[!0-9]*) cat "$out" >&2; echo 'permanent-size: could not parse permanent last address' >&2; exit 1;;
esac
if [ -n "$resident_limit" ] && [ "$resident" -gt "$resident_limit" ]; then
    cat "$out" >&2
    echo "permanent-size: resident $resident exceeds explicit limit $resident_limit" >&2
    exit 1
fi
if [ "$last" -gt "$last_limit" ]; then
    cat "$out" >&2
    echo "permanent-size: last address $last exceeds $last_limit" >&2
    exit 1
fi
if [ "$resident" -ge 16384 ]; then
    cat "$out" >&2
    echo "permanent-size: resident $resident violates architectural <16384-word limit" >&2
    exit 1
fi
if [ -n "$resident_limit" ]; then
    printf 'permanent-size: resident %s (<16384), explicit limit %s; last address %s/%s: PASS\n' \
        "$resident" "$resident_limit" "$last" "$last_limit"
else
    printf 'permanent-size: resident %s (<16384); last address %s/%s: PASS\n' \
        "$resident" "$last" "$last_limit"
fi
