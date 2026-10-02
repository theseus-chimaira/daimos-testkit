#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
pi=$(awk '$1 == "#define" && $2 == "PDP10_PI_HANDLER_CAPACITY" { gsub(/U$/, "", $3); print $3; exit }' \
    "$DAIMOS_REPO/system/kernel/core/kcore_pi.h")
mods=$(awk '$1 == "#define" && $2 == "MODULE_RUNTIME_MAX" { gsub(/U$/, "", $3); print $3; exit }' \
    "$DAIMOS_REPO/system/kernel/modules/module_runtime.h")
case "$pi:$mods" in
*[!0-9:]*|:*) echo "drm236-capacity: cannot parse capacities" >&2; exit 1;;
esac
[ "$pi" -ge 8 ] || { echo "drm236-capacity: PI handler capacity $pi < 8" >&2; exit 1; }
[ "$mods" -ge 20 ] || { echo "drm236-capacity: module owner capacity $mods < 20" >&2; exit 1; }
printf 'drm236-capacity: PI=%s MRES=%s: PASS\n' "$pi" "$mods"
