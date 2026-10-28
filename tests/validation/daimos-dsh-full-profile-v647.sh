#!/bin/sh
# Native full-profile login/DSH acceptance on freshly CLEAN D6FS media.
# Usage: script gcc|kcc 96|256
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
[ "$#" -eq 2 ] || { echo 'usage: test gcc|kcc 96|256' >&2; exit 2; }
compiler=$1
memory=$2
case "$compiler:$memory" in
gcc:96|kcc:96|gcc:256|kcc:256) ;;
*) echo 'unsupported compiler/memory pair' >&2; exit 2 ;;
esac
case "$compiler" in
gcc) cc_label=GCC ;;
kcc) cc_label=KCC ;;
esac
work=$(mktemp -d "$TMPDIR/daimos-dsh-v647-$compiler-$memory.XXXXXX")
passed=0
cleanup()
{
    if [ "$passed" -eq 1 ]; then
        rm -rf "$work"
    else
        echo "v647: retained diagnostics at $work" >&2
    fi
}
trap cleanup EXIT HUP INT TERM
build=${DAIMOS_DSH_FULL_BUILD_V647:-$work/build}
case "$memory" in
96) core=0300000 ;;
256) core=01000000 ;;
esac
PATH="$PDP10_PREFIX/bin:$PATH" make -s \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" BOOT_PROFILE=full ROOT=disk COMPILER="$compiler" \
    BOOT_CORE_WORDS="$core" SIMH_CPU_KWORDS="$memory" \
    > "$work/build.log" 2>&1 || {
        tail -35 "$work/build.log" >&2
        exit 1
    }
# Tests stopped at proc_boot_init can leave an otherwise valid image DIRTY.
# Never reuse such media for a subsequent login/DSH run: explicit CLEAN
# verification is required, and all guest writes occur on independent copies.
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" \
    > "$work/preflight.log" 2>&1 || {
        echo 'v647: source media not CLEAN; regenerate disk images' >&2
        cat "$work/preflight.log" >&2
        exit 1
    }
mkdir -p "$work/media"
cp -a "$build/disk" "$build/drum" "$work/media/"
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
    "$build/boot.ini" "$work/headless.ini" 32883 46883
sed -e "s|$build/disk/|$work/media/disk/|g" \
    -e "s|$build/drum/|$work/media/drum/|g" \
    "$work/headless.ini" > "$work/boot.ini"
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/pty" "$(dirname "$0")/../../tools/pty-run-v1.c"
cat > "$work/probes" <<EOF
probe dsh-echo
command ECHO DSH-V647-$cc_label-$memory-OK
contains DSH-V647-$cc_label-$memory-OK
end
probe external-true
command TRUE; ECHO STATUS:\$?
contains STATUS:0
end
probe orderly-halt
command HALT
terminal eof
end
EOF
"$(dirname "$0")/../../tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot.ini" \
    --pty-run "$work/pty" --login ROOT --probes "$work/probes" \
    --work-dir "$work/run" --markdown-report "$work/report.md" \
    --boot-timeout 120 --timeout 30 || {
        cat "$work/report.md" >&2 2>/dev/null || true
        exit 1
    }
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$work/media/disk" \
    > "$work/postflight.log" 2>&1 || {
        echo 'v647: shutdown left root media non-CLEAN' >&2
        cat "$work/postflight.log" >&2
        exit 1
    }
passed=1
echo "daimos-dsh-full-profile-v647: PASS ($compiler $memory K ROOT login, DSH, TRUE, HALT, CLEAN)"
