#!/bin/sh
# Physical 48K PDP-6 non-XIP LOWMEM boot/release gate.
# MEMFS and XIP are unavailable below 96K.
# 32K testing is deferred; historical 32K scripts remain untouched.
# Preserve separate build trees to prevent stale memory-size images.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
echo '=== v1486 physical 48K non-XIP LOWMEM boot ==='
DAIMOS_LOWMEM_BUILD_V1486="${LOWMEM_V1486_WORK_PREFIX:-$TMPDIR/daimos-lowmem-v1486}-48" \
DAIMOS_LOWMEM_KEEP_V1486="${LOWMEM_V1486_KEEP:-0}" \
    sh "$self/daimos-low-memory-boot-v1486.sh"
echo 'PASS v1486: physical 48K LOWMEM ROOT/DSH/MEMSTAT/DATE; MEMFS absent'
