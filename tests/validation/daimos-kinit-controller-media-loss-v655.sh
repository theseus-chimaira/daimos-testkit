#!/bin/sh
# Native PDP-6 KINIT: remove physical disk 0 after Stage1, before MINIT.
# The test never modifies its production image or source disk/drum media.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kinit-media-loss-v655.XXXXXX")
passed=0
cleanup()
{
    if [ "$passed" -eq 1 ]; then
        rm -rf "$work"
    else
        echo "v655 diagnostics retained: $work" >&2
    fi
}
trap cleanup EXIT HUP INT TERM
build=${DAIMOS_KINIT_CONTROLLER_BUILD_V655:-$work/build}
PATH="$PDP10_PREFIX/bin:$PATH" make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" BOOT_PROFILE=full ROOT=disk COMPILER=gcc \
    BOOT_CORE_WORDS=0300000 SIMH_CPU_KWORDS=96 \
    KINIT_STACK_WATERMARK=1 KINIT_STACK_RESERVE_WORDS=0400 \
    > "$work/build.log" 2>&1 || {
        tail -40 "$work/build.log" >&2
        exit 1
    }

# Reject mixed builds: the v653 test accidentally regenerated C with
# watermarking disabled while reusing an old instrumented assembler helper.
grep -Eq 'pushj[[:space:]]+17,kinit_stack_watermark_begin' \
    "$build/kinit-asm/kinit.s" || {
        echo 'v655: KINIT C lacks watermark initialization' >&2; exit 1;
    }
grep -Fqx '.set KINIT_STACK_WATERMARK,1' \
    "$build/kinit-asm/kinit_io_pdp6.s"
grep -Fqx '.set KINIT_STACK_RESERVE_WORDS,0400' \
    "$build/kinit-asm/kinit_io_pdp6.s"

entry=$(awk '$1 == "kinit_enter" {print $2; exit}' "$build/kinit.map")
watermark=$(awk '$1 == "kinit_stack_highwater" {print $2; exit}' \
    "$build/kcore.map")
case "$entry:$watermark" in ''|*[!0-7:]*|:*|*:) echo 'missing linked symbols' >&2; exit 1;; esac
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" \
    > "$work/preflight.log" 2>&1 || {
        echo 'v655 requires pristine CLEAN source D6FS' >&2
        cat "$work/preflight.log" >&2
        exit 1
    }
cp -a "$build/disk" "$work/disk"
cp -a "$build/drum" "$work/drum"
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
    "$build/boot.ini" "$work/headless.ini" 32865 46865
sed -e "s|$build/disk/|$work/disk/|g" \
    -e "s|$build/drum/|$work/drum/|g" \
    "$work/headless.ini" > "$work/isolated.ini"

# Stage1 already read the boot image. Removing the controller's root
# disk at KINIT entry exercises real DSK not-ready/media-loss behavior,
# not a simulated BLOCKSET return code.
awk -v entry="$entry" -v watermark="$watermark" '
    /^go 020$/ {
        print "break " entry
        print
        print "detach dsk0"
        print "nobreak"
        print "continue"
        next
    }
    /^exit$/ {print "examine " watermark}
    {print}
' "$work/isolated.ini" > "$work/failure.ini"
set +e
(cd "$build" && TERM=dumb timeout -k 2s 45s "$PDP10_PREFIX/bin/pdp6" \
    "$work/failure.ini") > "$work/boot.log" 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] || { tail -55 "$work/boot.log" >&2; exit 1; }
grep -Fq "Breakpoint, PC: $(printf '%06o' "$((0$entry))")" \
    "$work/boot.log"
grep -q 'HALT instruction' "$work/boot.log"
grep -Eq '^MEM[[:space:]]+96 K' "$work/boot.log"
grep -Eq '^DSK270[[:space:]]+OK' "$work/boot.log"
if grep -Eq 'INIT V1|D6FS[[:space:]]+LOADED' "$work/boot.log"; then
    echo 'v655: unexpected continued root mount after media loss' >&2
    exit 1
fi
short=$(printf '%o' "$((0$watermark))")
value=$(awk -v addr="$short" '$1 == addr ":" {print $2; exit}' \
    "$work/boot.log")
case "$value" in ''|*[!0-7]*) echo 'v655: no high-water reading' >&2; exit 1;; esac
used=$((0$value))
if [ "$used" -le 0 ] || [ "$used" -ge "$((0400))" ]; then
    echo "v655: stack watermark outside 0400 reserve: $value" >&2
    exit 1
fi
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" \
    > "$work/postflight.log" 2>&1 || {
        echo 'v655: original D6FS unexpectedly changed' >&2
        exit 1
    }
passed=1
printf 'daimos-kinit-controller-media-loss-v655: PASS (DSK0 detached; stack %o octal / %d words)\n' \
    "$used" "$used"
