#!/bin/sh
# Native PDP-6 32K TSFS boot regression: 384-word KINIT stack + optional DRM.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"
work="$TMPDIR/daimos-kinit-stack384-drm-v506-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
PATH="$PDP10_PREFIX/bin:$PATH" make -s -C "$DAIMOS_REPO/system/boot/pdp6" \
    image BUILD="$work/build" BOOT_PROFILE=lowmem ROOT=tape \
    COMPILER=gcc KINIT_STACK_RESERVE_WORDS=0600 > "$work/build.log" 2>&1 || {
    tail -30 "$work/build.log" >&2
    exit 1
}
# Requiring the DRM entry in the final MRES/initialization map prevents
# the ordinary non-DRM lowmem boot from masquerading as a pass.
grep -q 'drm236_mres_package' "$work/build/kinit.map"
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
    "$work/build/boot.ini" "$work/build/boot.headless.ini" 32621 46621
set +e
(cd "$work/build"; TERM=dumb timeout -k 2s 35s \
    "$PDP10_PREFIX/bin/pdp6" boot.headless.ini) > "$work/boot.log" 2>&1
rc=$?
set -e
[ "$rc" -eq 124 ] || [ "$rc" -eq 0 ] || {
    tail -60 "$work/boot.log" >&2; exit 1;
}
for marker in 'MEM                                  32 K' \
    'DTC                                   OK' \
    'DRM236                                OK' 'INIT V1'; do
    grep -Fq "$marker" "$work/boot.log" || {
        echo "missing boot marker: $marker" >&2
        tail -60 "$work/boot.log" >&2
        exit 1
    }
done
echo 'daimos-kinit-stack384-drm-v506: PASS (32K DRM + TSFS -> INIT)'
