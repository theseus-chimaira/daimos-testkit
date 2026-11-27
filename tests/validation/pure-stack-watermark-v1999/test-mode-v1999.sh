#!/bin/sh
# Check flag changes in the same inner build, including both C fillers.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
export PATH="$PDP10_PREFIX/bin:$PATH"
mkdir -p "$TMPDIR"
w=$(mktemp -d "$TMPDIR/proc-stack-mode-v1999.XXXXXX")
echo "mode evidence $w"
for mode in 0 1 0; do
    make -s -C "$DAIMOS_REPO/system/kernel" BUILD="$w" COMPILER=gcc PDP10_PREFIX="$PDP10_PREFIX" PROC_STACK_WATERMARK="$mode" "$w/proc_pdp6.s" "$w/proc_run.s" "$w/kinit.s" "$w/proc_late.s"
    for f in proc_pdp6 proc_run; do
        grep -q "^.set PROC_STACK_WATERMARK,$mode$" "$w/$f.s"
    done
    if [ "$mode" = 1 ]; then
        for f in kinit proc_late; do
            if cmp -s "$w/$f.s" "$w/$f.off"; then
                echo "FAIL unchanged $f canary generation" >&2
                exit 1
            fi
        done
    elif [ -f "$w/kinit.off" ]; then
        cmp "$w/kinit.s" "$w/kinit.off"
        cmp "$w/proc_late.s" "$w/proc_late.off"
    else
        cp "$w/kinit.s" "$w/kinit.off"
        cp "$w/proc_late.s" "$w/proc_late.off"
    fi
    echo "PASS same-tree watermark mode $mode"
done
if make -s -C "$DAIMOS_REPO/system/kernel" BUILD="$w" PROC_STACK_WATERMARK=2 "$w/proc_pdp6.s" >"$w/invalid.log" 2>&1; then
    exit 1
fi
grep -q 'PROC_STACK_WATERMARK must be 0 or 1' "$w/invalid.log"
echo 'PASS invalid mode rejected'
