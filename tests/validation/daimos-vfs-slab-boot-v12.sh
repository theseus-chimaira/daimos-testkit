#!/bin/sh
# Diagnostic PDP-6 boot check for KINIT-published MM-backed VFS tables.
# The unrelated, pre-existing DSH size gate is overridden for this diagnostic
# only. Do NOT interpret this as a production-image size acceptance test.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-vfs-slab-boot-v12.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
testkit=$(CDPATH= cd -- "$self/../.." && pwd -P)
bootdir=$DAIMOS_REPO/system/boot/pdp6
build=$work/build
image_build=$build/system/boot/pdp6
dcs_port=$((16000 + ($$ % 12000)))
ge_port=$((dcs_port + 20000))

${CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    "$testkit/tools/pty-run-v1.c" -o "$work/pty-relay"
${CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    "$testkit/tools/tcp-run-v1.c" -o "$work/tcp-relay"

if ! make -C "$bootdir" image BOOT=dsk ROOT=disk \
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    DSH_IMAGE_LIMIT=037000 SIMH_DCS0_PORT="$dcs_port" \
    SIMH_GE0_PORT="$ge_port" >"$work/build.log" 2>&1; then
    tail -50 "$work/build.log" >&2
    exit 1
fi

cat > "$work/probes.txt" <<'EOF'
probe vfs-slab-kinit-login-v12
command ECHO VFS12BOOTOK
contains VFS12BOOTOK
end
EOF

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$TMPDIR" \
    "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" --dofile "$image_build/boot.ini" \
    --pty-run "$work/pty-relay" --tcp-run "$work/tcp-relay" \
    --dcs-port "$dcs_port" --boot-timeout 120 --timeout 20 \
    --login ROOT --probes "$work/probes.txt" \
    --work-dir "$work/simh-run" \
    --markdown-report "$work/boot-report.md"

printf '%s\n' \
    'vfs-slab-boot-v12: PASS (PDP-6 ROOT login with diagnostic DSH size override)'
