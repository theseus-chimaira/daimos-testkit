#!/bin/sh
# Validate the 32K bootstrap stack-bound diagnostic without boot media.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kinit-stack-v637.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/kinit.map" <<'EOF'
__kinit_image_start 030000
__kinit_image_end 077236
__kcore_load_begin 030020
__kcore_load_end 030100
kinit_enter 030000
EOF
echo '__kcore_low_init_end 000140' > "$work/kcore.map"
: > "$work/kinit.stream"
: > "$work/kcore.stream"
if "$DAIMOS_REPO/system/boot/pdp6/image/mkimage.sh" \
    --map "$work/kinit.map" --input "$work/kinit.stream" \
    --kcore "$work/kcore.stream" --kcore-map "$work/kcore.map" \
    --core-words 0100000 --stack-words 0600 \
    --output "$work/out" > "$work/log" 2>&1; then
        echo 'v637: overflowing KINIT was accepted' >&2
        exit 1
fi
grep -q 'image end 77236 exceeds stack-safe limit 77200 by 36 words' "$work/log"
grep -q 'KINIT image leaves less than the configured stack reserve' "$work/log"
test ! -e "$work/out"
echo 'daimos-kinit-stack-bound-v637: PASS'
