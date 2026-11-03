#!/bin/sh
# Compile the real SIMH display frontend with only its video API mocked.
set -eu

: "${TMPDIR:=${HOME}/tmp}"
: "${SIMS_REPO:?SIMS_REPO must name the sims source checkout}"
cc=${CC:-cc}
sdl_cflags=$(sdl2-config --cflags)
sim_ws_source=${SIM_WS_SOURCE:-$SIMS_REPO/display/sim_ws.c}
src=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$TMPDIR/simh-sdl-window-open-failure-v1-$$
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

"$cc" -std=c99 -O1 -ffunction-sections -fdata-sections \
    -DUSE_SIM_VIDEO -DHAVE_LIBSDL $sdl_cflags \
    -I"$SIMS_REPO" -I"$SIMS_REPO/display" \
    -c "$sim_ws_source" -o "$work/sim_ws.o"
"$cc" -std=c89 -O1 -ffunction-sections -fdata-sections \
    -DUSE_SIM_VIDEO -DHAVE_LIBSDL $sdl_cflags \
    -I"$SIMS_REPO" -I"$SIMS_REPO/display" \
    -c "$src/simh-sdl-window-open-failure-v1.c" -o "$work/check.o"
"$cc" -Wl,--gc-sections -o "$work/check" \
    "$work/sim_ws.o" "$work/check.o"
"$work/check"
echo 'simh-sdl-window-open-failure-v1: PASS'
