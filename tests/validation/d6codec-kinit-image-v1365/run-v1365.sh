#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/d6codec-kinit-image-v1365"
work="$TMPDIR/d6codec-kinit-v1365"
mkdir -p "$work"

# The first runner creates only versioned test artifacts, including the
# real freshly linked KINIT grouped stream and all five Stage-1 sources.
sh "$here/run-dtc-v1365.sh"
sh "$here/run-mtc-v1365.sh"
sh "$here/run-ptr-v1365.sh"
sh "$here/run-dsk-v1365.sh"
sh "$here/run-drm-v1365.sh"
sh "$here/run-negative-dtc-v1365.sh"

# A 32K profile must reject this full-sized KINIT before publishing
# an output file, as must a configuration with no room for the stack.
generator="$here/make_grouped_kinit_v1365.py"
input="$DAIMOS_REPO/build/system/boot/pdp6/kinit.words"
for case in 32k no-stack; do
    target="$work/rejected-$case-v1365.words"
    rm -f "$target"
    case "$case" in
        32k) core=0100000; stack=0400 ;;
        no-stack) core=01000000; stack=0777777 ;;
    esac
    if python3 -B "$generator" "$input" "$target" "$core" "$stack" \
        >"$work/rejected-$case-v1365.log" 2>&1; then
        echo "v1365: invalid $case physical geometry was accepted" >&2
        exit 1
    fi
    test ! -e "$target" || {
        echo "v1365: rejected $case produced a partial image" >&2
        exit 1
    }
    echo "PASS v1365: host refuses $case image without a partial output"
done
echo 'PASS v1365: five real grouped Stage-1 device boots and two DTC failure paths'
