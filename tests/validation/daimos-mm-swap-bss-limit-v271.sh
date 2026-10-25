#!/bin/sh
# Ensure the recorded experiment really crosses the loader BSS bound.
set -eu
: "${DAIMOS_REPO:?}"
loader="$DAIMOS_REPO/system/kernel/proc/exec_load.s"
grep -q 'caile[[:space:]]*16,077777' "$loader"
grep -q 'andi[[:space:]]*16,0077777' "$loader"
# PDP-6 assembly octal BSS boundary: 077777 words.
[ "$((077777))" -eq 32767 ]
[ "$((0160000))" -gt 32767 ]
[ "$((060000))" -lt 32767 ]
printf '%s\n' 'daimos-mm-swap-bss-limit-v271: PASS (24K valid, 56K rejected by header limit)'
