#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-logstore-runtime-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
out="$work/simh.out"
clean="$work/simh.clean"

cleanup()
{
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work"

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null
boot="$build/system/boot/pdp6"

size=`PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -s -C "$DAIMOS_REPO/system/boot/pdp6" permanent-size \
    BUILD="$boot" PDP10_PREFIX="$PDP10_PREFIX"`
printf '%s\n' "$size" | grep -Eq '^MRES logstore[[:space:]]+[0-7]+[[:space:]]+[1-9][0-9]*$' || {
        printf '%s\n' "$size" >&2
        echo "$tag: LOGSTORE MRES missing from permanent-size accounting" >&2
        exit 1
}

sed '/^go 020$/,$d' "$boot/boot.ini" >"$work/boot.ini"
cat >>"$work/boot.ini" <<'SIMH_EOF'
expect "LOGIN: "
go 020
exit
SIMH_EOF
(
        cd "$boot"
        TERM=dumb timeout -k 2s 30s "$PDP10_PREFIX/bin/pdp6" "$work/boot.ini"
) >"$out" 2>&1 || {
        cat "$out" >&2
        echo "$tag: simulator boot failed" >&2
        exit 1
}
tr -d '\r' <"$out" >"$clean"
grep -Eq '^LOGSTR[[:space:]]+LOADED' "$clean" || {
        cat "$clean" >&2
        echo "$tag: runtime LOGSTORE MRES did not load" >&2
        exit 1
}
grep -q 'LOGIN: ' "$clean" || {
        cat "$clean" >&2
        echo "$tag: boot did not reach LOGIN" >&2
        exit 1
}

printf '%s\n' "$tag: PASS (cold recovery -> runtime MRES, permanent-size accounted)"
