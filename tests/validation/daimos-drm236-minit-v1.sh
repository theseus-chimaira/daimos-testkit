#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

work="$TMPDIR/daimos-drm236-minit-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

make -C "$DAIMOS_REPO/system/boot/pdp6" permanent-size \
        BUILD="$work/boot" PDP10_PREFIX="$PDP10_PREFIX" \
        TMPDIR="$TMPDIR" >/dev/null

test -f "$work/boot/drm-mres.dobj" || {
        echo "drm236-minit: missing drm-mres.dobj" >&2
        exit 1
}
test -f "$work/boot/drm-mres.map" || {
        echo "drm236-minit: missing drm-mres.map" >&2
        exit 1
}
for symbol in drm236_pi_handler drm236_read_block_service drm236_write_block_service
do
        grep -q "$symbol" "$work/boot/drm-mres.map" || {
                echo "drm236-minit: missing MRES export $symbol" >&2
                exit 1
        }
done

grep -q 'drm236_minit' "$work/boot/kinit-asm/module_minit.s" || {
        echo "drm236-minit: drm236_minit is not generated into KINIT" >&2
        exit 1
}
grep -q 'drm236_minit,,drm236_mres_package' \
        "$DAIMOS_REPO/system/kernel/modules/module_table.s" || {
        echo "drm236-minit: DRM236 MINIT/MRES pair is absent from module table" >&2
        exit 1
}

printf '%s\n' 'drm236-minit: PASS (MRES packaged and DRM236 MINIT linked)'
