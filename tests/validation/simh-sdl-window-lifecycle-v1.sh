#!/bin/sh
# Exercise the SDL2 event loop with repeated PDP-6 video window lifetimes.
# This is a simulator regression, not a DAIMOS guest test.
set -eu

: "${TMPDIR:=${HOME}/tmp}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
simh=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}
driver=${SDL_VIDEODRIVER:-dummy}
work=$TMPDIR/simh-sdl-window-lifecycle-v1-$$
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

cat > "$work/events.ini" <<'EOF'
set dpy GUI
set dpy enabled
set wcnsls cscope
set wcnsls enabled
set wcnsls disabled
set wcnsls enabled
set wcnsls disabled
set wcnsls enabled
set wcnsls disabled
set wcnsls enabled
set wcnsls disabled
set wcnsls enabled
set wcnsls disabled
set dpy disabled
exit
EOF

set +e
(cd "$work" && SDL_VIDEODRIVER="$driver" SDL_AUDIODRIVER=dummy \
    TERM=dumb timeout -k 2s 30s "$simh" events.ini) >"$work/output" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ] || grep -Eiq \
    'Segmentation fault|AddressSanitizer|File open error|Error Creating Video Window|Unrecognized window event' \
    "$work/output"; then
    cat "$work/output" >&2
    echo "simh-sdl-window-lifecycle-v1: FAIL (simulator=$rc, video driver=$driver)" >&2
    exit 1
fi

echo "simh-sdl-window-lifecycle-v1: PASS (video driver=$driver)"
