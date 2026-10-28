#!/bin/sh
# Stop at process boot handoff: test 32K KINIT without userspace execution.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kinit-only-v641.XXXXXX")
passed=0
cleanup()
{
    if [ "$passed" -eq 1 ]; then
        rm -rf "$work"
    else
        echo "v641: failed-test diagnostics retained at $work" >&2
    fi
}
trap cleanup EXIT HUP INT TERM
build=${DAIMOS_KINIT_KERNEL_ONLY_BUILD_V641:-$work/build}
PATH="$PDP10_PREFIX/bin:$PATH" make -s \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" BOOT_PROFILE=lowmem ROOT=tape COMPILER=gcc \
    > "$work/build.log" 2>&1 || { tail -35 "$work/build.log" >&2; exit 1; }
end=$(awk '$1 == "__kinit_image_end" { print $2; exit }' "$build/kinit.map")
entry=$(awk '$1 == "proc_boot_init" { print $2; exit }' "$build/kinit.map")
case "$end:$entry" in *[!0-7:]*|:*|*:) echo 'missing image or handoff symbol' >&2; exit 1 ;; esac
[ "$((0$end))" -le "$((0100000 - 0600))" ] || {
    echo 'v641: 32K stack reserve violated' >&2; exit 1
}
grep -q '^set cpu 32k$' "$build/boot.ini"
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
    "$build/boot.ini" "$work/headless.ini" 32859 46859
awk -v entry="$entry" '
    /^go 020$/ { print "break " entry }
    { print }
' "$work/headless.ini" > "$work/stop.ini"
set +e
(cd "$build" && TERM=dumb timeout -k 2s 25s \
    "$PDP10_PREFIX/bin/pdp6" "$work/stop.ini") > "$work/boot.log" 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] || { tail -60 "$work/boot.log" >&2; exit 1; }
grep -Fq "Breakpoint, PC: $entry " "$work/boot.log"
grep -Eq '^MEM[[:space:]]+32 K' "$work/boot.log"
grep -Eq 'DSK270[[:space:]]+OK' "$work/boot.log"
grep -Eq 'DTC[[:space:]]+OK' "$work/boot.log"
grep -Eq 'DTFS[[:space:]]+LOADED' "$work/boot.log"
if grep -q 'INIT V1' "$work/boot.log"; then
    echo 'v641: userspace ran before the breakpoint' >&2
    exit 1
fi
passed=1
echo "daimos-kinit-kernel-only-v641: PASS (32K KINIT stopped before proc_boot_init at $entry)"
