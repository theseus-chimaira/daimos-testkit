#!/bin/sh
# Native KCC full-profile 256K kernel boot before userspace handoff.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-full256-v645.XXXXXX")
passed=0
trap 'if [ "$passed" -eq 1 ]; then rm -rf "$work"; else echo "v645 diagnostics retained: $work" >&2; fi' EXIT HUP INT TERM
build=${DAIMOS_KINIT_FULL256_KCC_BUILD_V645:-$work/build}
PATH="$PDP10_PREFIX/bin:$PATH" make -s -C "$DAIMOS_REPO/system/boot/pdp6" \
    image BUILD="$build" BOOT_PROFILE=full ROOT=disk COMPILER=kcc \
    BOOT_CORE_WORDS=01000000 SIMH_CPU_KWORDS=256 > "$work/build.log" 2>&1 || {
        tail -40 "$work/build.log" >&2; exit 1;
    }
entry=$(awk '$1 == "proc_boot_init" {print $2; exit}' "$build/kinit.map")
end=$(awk '$1 == "__kinit_image_end" {print $2; exit}' "$build/kinit.map")
case "$entry:$end" in *[!0-7:]*|:*|*:) echo 'missing link symbols' >&2; exit 1;; esac
[ "$((0$end + 0600))" -le "$((01000000))" ] || {
    echo 'v645: full KINIT violates 256K stack limit' >&2; exit 1;
}
grep -q '^set cpu 256k$' "$build/boot.ini"
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
    "$build/boot.ini" "$work/headless.ini" 32973 46973
awk -v entry="$entry" '/^go 020$/ { print "break " entry } { print }' \
    "$work/headless.ini" > "$work/stop.ini"
set +e
(cd "$build" && TERM=dumb timeout -k 2s 40s \
    "$PDP10_PREFIX/bin/pdp6" "$work/stop.ini") > "$work/boot.log" 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] || { tail -60 "$work/boot.log" >&2; exit 1; }
grep -Fq "Breakpoint, PC: $entry " "$work/boot.log"
grep -Eq '^MEM[[:space:]]+256 K' "$work/boot.log"
for marker in 'DSK270                                OK' \
    'DRM236                                OK' \
    'BSET                              LOADED' \
    'D6FS                              LOADED' \
    'MEMFS                             LOADED'; do
    grep -Fq "$marker" "$work/boot.log" || {
        echo "v645 missing: $marker" >&2; exit 1;
    }
done
if grep -q 'INIT V1' "$work/boot.log"; then
    echo 'v645: userspace ran before breakpoint' >&2; exit 1
fi
passed=1
echo 'daimos-kinit-full256-kcc-v645: PASS (full 256K KCC KINIT boundary)'
