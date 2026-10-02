#!/bin/sh
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"

tag=daimos-no-kernel-uuo-v1

hits=$(grep -RniE '^[[:space:]]*uuo[[:space:]]+' \
    "$DAIMOS_REPO/system/kernel" --include='*.s' --include='*.S' || true)
if [ -n "$hits" ]; then
        printf '%s\n' "$hits" >&2
        echo "$tag: executive-mode UUO instruction found in resident kernel source" >&2
        exit 1
fi

printf '%s\n' "$tag: PASS (no executive-mode UUO traps in kernel source)"
