#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
simh=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}
tag=daimos-dsk-root-discovery-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
boot="$build/system/boot/pdp6"
out="$work/cty.out"
sim_pid=

cleanup()
{
        if [ -n "$sim_pid" ] && kill -0 "$sim_pid" 2>/dev/null; then
                kill "$sim_pid" 2>/dev/null || true
                wait "$sim_pid" 2>/dev/null || true
        fi
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work"

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    ROOT=auto BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null

# The default image intentionally has only DSK0 attached.  This catches the
# regression where KINIT kept probing absent DSK1..3 after root 0 was complete
# and left the Type-270 path unusable before D6FS mounted it.
grep -F "attach -q dsk0 $boot/disk/dsk0.dsk" "$boot/boot.ini" >/dev/null || {
        echo "$tag: DSK0 root media is not attached" >&2
        exit 1
}
if grep -Eq '^attach .*dsk[1-3] ' "$boot/boot.ini"; then
        echo "$tag: acceptance requires DSK1..3 to remain unattached" >&2
        exit 1
fi

(
        cd "$boot"
        TERM=dumb exec "$simh" "$boot/boot.ini"
) >"$out" 2>&1 &
sim_pid=$!

i=0
while [ "$i" -lt 900 ]; do
        if tr -d '\r' <"$out" 2>/dev/null | grep -F 'LOGIN: ' >/dev/null 2>&1; then
                break
        fi
        kill -0 "$sim_pid" 2>/dev/null || break
        sleep 0.1
        i=$((i + 1))
done

clean="$work/cty.clean"
tr -d '\r' <"$out" >"$clean"
if ! grep -F 'LOGIN: ' "$clean" >/dev/null 2>&1; then
        cat "$clean" >&2
        echo "$tag: DSK root did not reach LOGIN" >&2
        exit 1
fi
grep -Eq '^D6FS[[:space:]]+LOADED' "$clean" || {
        cat "$clean" >&2
        echo "$tag: D6FS root did not load" >&2
        exit 1
}
grep -F 'INIT V1' "$clean" >/dev/null || {
        cat "$clean" >&2
        echo "$tag: INIT did not start" >&2
        exit 1
}
if grep -F '?RT' "$clean" >/dev/null 2>&1; then
        cat "$clean" >&2
        echo "$tag: reproduced root-selection ?RT halt" >&2
        exit 1
fi

printf '%s\n' "$tag: PASS (DSK0 discovered without probing absent trailing units)"
