#!/bin/sh
# Production PDP-6 disk-boot acceptance on the actual DCS0 LOGIN path.
# CTY carries startup diagnostics; DCS0 carries the interactive login.
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:=$HOME/tmp}"
: "${BUILD:?BUILD must be set}"
export TMPDIR

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd -P)
compiler=${COMPILER:-kcc}
simh=${SIMH_PDP6:-"$PDP10_PREFIX/bin/pdp6"}
cc=${HOST_CC:-cc}
work="$BUILD"
pty="$work/pty-run-v121"
tcp="$work/tcp-run-v121"
run="$work/kernel-dcs-v121"
probe="$testkit/probes/daimos-three-emulator-boot-v24.txt"
port=$((24000 + ($$ % 9000)))
ge_port=$((36000 + ($$ % 9000)))

mkdir -p "$work"
"$cc" -std=c99 -O2 -Wall -Wextra -Werror -o "$pty" "$testkit/tools/pty-run-v1.c"
"$cc" -std=c99 -O2 -Wall -Wextra -Werror -o "$tcp" "$testkit/tools/tcp-run-v1.c"

# This is functional 256K boot acceptance. The strict 32K image-size gate
# remains separately enforced elsewhere and is explicitly deferred here.
PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    COMPILER="$compiler" BUILD="$work" BUILD_ROOT="$work/daimos-build" \
    PDP10_PREFIX="$PDP10_PREFIX" D6FS_SPARE_BLOCKS="${D6FS_SPARE_BLOCKS:-0}" \
    DSH_IMAGE_LIMIT=037000 SIMH_DCS0_PORT="$port" SIMH_GE0_PORT="$ge_port"

"$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot.ini" \
    --simh "$simh" --pty-run "$pty" --tcp-run "$tcp" \
    --dcs-port "$port" --login ROOT --boot-timeout 180 --timeout 45 \
    --probes "$probe" --work-dir "$run" \
    --markdown-report "$work/kernel-dcs-v121.md"

# An interactive DSH success alone is insufficient: require the actual
# production kernel boot banner and the initialized blockset provider.
version=$(cat "$DAIMOS_REPO/VERSION")
tr -d '\r' < "$run/simh.log" > "$work/cty-normalized-v121.log"
if ! grep -E "^DAIMON[[:space:]]+V$version([[:space:]]|$)" \
        "$work/cty-normalized-v121.log" >/dev/null; then
    echo "kernel-boot-dcs-v121: production DAIMON banner missing" >&2
    exit 1
fi
if ! grep -E '^BSET[[:space:]]+LOADED([[:space:]]|$)' \
        "$work/cty-normalized-v121.log" >/dev/null; then
    echo "kernel-boot-dcs-v121: kernel BSET initialization missing" >&2
    exit 1
fi

echo "kernel-boot-dcs-v121: PASS (kernel CTY boot, DCS0 ROOT, DSH ECHO/PWD)"
