#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
simh=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}
tag=daimos-drm-stage1-boot-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
boot="$build/system/boot/pdp6"
out="$work/cty.out"
ini="$work/boot-drm-only.ini"
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
    ROOT=drum BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null

grep -F "attach -q ptr $boot/stage1-drm.pt" "$boot/boot.ini" >/dev/null || {
        echo "$tag: ROOT=drum did not select DRM Stage1" >&2
        exit 1
}
grep -Eq '^deposit SW 3$' "$boot/boot.ini" || {
        echo "$tag: drum root switch is not 3" >&2
        exit 1
}
cmp "$boot/disk/dsk0.dsk" "$boot/media/dr0.drm" >/dev/null || {
        echo "$tag: DR0 does not contain the generated D6FS bootset" >&2
        exit 1
}

# Prove the bootstrap stream itself does not depend on DSK270.  Keep the
# controller enabled so ordinary module initialization is unchanged, but do
# not attach DSK0 media for this acceptance run.
sed '/^attach -q dsk0 /d' "$boot/boot.ini" > "$ini"
(
        cd "$boot"
        TERM=dumb exec "$simh" "$ini"
) >"$out" 2>&1 &
sim_pid=$!

wait_for()
{
        pattern=$1
        ticks=${2:-900}
        i=0
        while [ "$i" -lt "$ticks" ]; do
                if tr -d '\r' <"$out" 2>/dev/null | grep -F "$pattern" >/dev/null 2>&1; then
                        return 0
                fi
                kill -0 "$sim_pid" 2>/dev/null || return 1
                sleep 0.1
                i=$((i + 1))
        done
        return 1
}

if ! wait_for 'LOGIN: ' 900; then
        tr -d '\r' <"$out" >&2 || true
        echo "$tag: direct DRM Stage1 boot did not reach LOGIN" >&2
        exit 1
fi

clean="$work/cty.clean"
tr -d '\r' <"$out" >"$clean"
grep -Eq '^DRM236[[:space:]]+OK' "$clean" || {
        cat "$clean" >&2
        echo "$tag: DRM236 MRES did not initialize" >&2
        exit 1
}
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

printf '%s\n' "$tag: PASS (DRM Stage1 -> DRM/D6FS -> INIT -> LOGIN with DSK0 unattached)"
