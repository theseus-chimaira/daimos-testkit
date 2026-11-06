#!/bin/sh
# Read-only PI, disk request and slot-0 stack diagnostic. Requires fresh media.
set -eu
: "${PDP10_PREFIX:?}" "${F07_GUEST_BUILD:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
build=$F07_GUEST_BUILD
test -f "$build/boot.ini" && test -f "$build/kcore.map" || {
    echo 'v1250: full guest with exact map required' >&2
    exit 2
}
work=$(mktemp -d "$TMPDIR/daimos-f07-slot0-v1250.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 "$self/daimos-f07-slot0-event-v1250.py" \
    "$build/boot.ini" "$build/kcore.map" "$work/boot.v1250.ini"
out=${F07_EVENT_EVIDENCE:-$TMPDIR/daimos-f07-slot0-event-v1250.log}
test ! -e "$out" || {
    echo 'v1250: evidence destination already exists' >&2
    exit 2
}
printf 'v1250: guest %s\n' "$build"
printf 'v1250: capturing to %s\n' "$out"
set +e
(cd "$build" && TERM=dumb SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy timeout -k 2s 900s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" "$work/boot.v1250.ini") > "$out" 2>&1
rc=$?
set -e
if grep -aFq '?RT' "$out" || ! grep -aFq '<+' "$out"; then
    echo 'v1250: invalid boot media or missing RUN progress' >&2
    exit 1
fi
printf 'v1250: simulator exit %d; snapshot in %s\n' "$rc" "$out"
exit "$rc"
