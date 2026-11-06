#!/bin/sh
# Replay an existing full guest with map-resolved PI/scheduler observations.
# Stop the simulator with SIGINT to record the exact native state.
set -eu
: "${PDP10_PREFIX:?}" "${F07_GUEST_BUILD:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
build=$F07_GUEST_BUILD
test -f "$build/boot.ini" && test -f "$build/kcore.map" || {
    echo 'v1249: complete guest boot.ini and kcore.map required' >&2
    exit 2
}
work=$(mktemp -d "$TMPDIR/daimos-f07-pi-v1249.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 "$self/daimos-f07-pi-map-probe-v1249.py" \
    "$build/boot.ini" "$build/kcore.map" "$work/boot.v1249.ini"
out=${F07_PI_EVIDENCE:-$TMPDIR/daimos-f07-pi-v1249.log}
test ! -e "$out" || {
    echo "v1249: evidence already exists: $out" >&2
    exit 2
}
echo "v1249: guest $build"
echo "v1249: retained evidence $out"
echo 'v1249: SIGINT the simulator when the guest stalls'
set +e
(cd "$build" && TERM=dumb SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy timeout -k 2s 900s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" "$work/boot.v1249.ini") > "$out" 2>&1
rc=$?
set -e
if grep -aFq '?RT' "$out"; then
    echo 'v1249: unusable root media; PI snapshot is not F07 evidence' >&2
    exit 1
fi
if ! grep -aFq '<+' "$out"; then
    echo 'v1249: missing concurrent RUN progress' >&2
    exit 1
fi
echo "v1249: simulator exit $rc; PI and exact map addresses in $out"
exit "$rc"
