#!/bin/sh
# D6FS mounts successfully but /SYSTEM/INIT is absent or not a regular file.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kinit-init-v653.XXXXXX")
passed=0
trap 'if [ "$passed" -eq 1 ]; then rm -rf "$work"; else echo "v653 diagnostics: $work" >&2; fi' EXIT HUP INT TERM
build=${DAIMOS_KINIT_INIT_BUILD_V653:-$work/build}
PATH="$PDP10_PREFIX/bin:$PATH" make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" BOOT_PROFILE=full ROOT=disk COMPILER=gcc \
    BOOT_CORE_WORDS=0300000 SIMH_CPU_KWORDS=96 \
    > "$work/build.log" 2>&1 || { tail -30 "$work/build.log" >&2; exit 1; }
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" > "$work/source-check.log" 2>&1 || {
    echo 'v653 source diskset must be CLEAN' >&2; exit 1;
}
for mode in missing directory; do
    run="$work/$mode"
    mkdir -p "$run"
    cp -a "$build/disk" "$run/disk"
    if [ "$mode" = directory ]; then
        "$PDP10_PREFIX/bin/mkd6fs" -n 4 -d "$run/disk" \
            -D /SYSTEM:0555 -D /SYSTEM/INIT:0555 > "$run/format.log" 2>&1
    else
        "$PDP10_PREFIX/bin/mkd6fs" -n 4 -d "$run/disk" \
            -D /SYSTEM:0555 > "$run/format.log" 2>&1
    fi
    "$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$run/disk" \
        > "$run/preflight.log" 2>&1
    grep -q 'state=CLEAN' "$run/preflight.log"
    "$(dirname "$0")/../lib/daimos-simh-headless.sh" \
        "$build/boot.ini" "$run/base.ini" 32865 46865
    sed "s|$build/disk/|$run/disk/|g" "$run/base.ini" > "$run/boot.ini"
    set +e
    (cd "$build" && TERM=dumb timeout -k 2s 45s \
        "$PDP10_PREFIX/bin/pdp6" "$run/boot.ini") > "$run/boot.log" 2>&1
    rc=$?
    set -e
    [ "$rc" -eq 0 ] || { tail -30 "$run/boot.log" >&2; exit 1; }
    grep -Fq '?RT' "$run/boot.log"
    grep -q 'HALT instruction' "$run/boot.log"
    grep -Eq 'D6FS[[:space:]]+LOADED' "$run/boot.log"
    if grep -q 'INIT V1' "$run/boot.log"; then
        echo "v653 $mode unexpectedly started INIT" >&2; exit 1
    fi
    # A writable root is marked DIRTY before the expected fatal HALT.
    # This is correct crash-state behavior, not a clean shutdown.
    if "$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$run/disk" \
        > "$run/postflight.log" 2>&1; then
        echo "v653 $mode unexpectedly remained CLEAN" >&2; exit 1
    fi
    grep -q 'state=DIRTY' "$run/postflight.log"
    echo "v653 $mode: PASS (?RT and expected DIRTY mount state)"
done
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" > "$work/unchanged.log" 2>&1
passed=1
echo 'daimos-kinit-init-validation-v653: PASS (missing and directory INIT)'
