#!/bin/sh
# Verify that the D6FS-only boot image cannot accidentally carry DTFS/TSFS.
set -eu

: "${DAIMOS_REPO:?}"
: "${TMPDIR:?}"
work="$TMPDIR/daimos-root-tapefs-selection-20261012-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

for root in disk drum tape auto; do
        build="$work/$root"
        make -s -C "$DAIMOS_REPO/system/boot/pdp6" ROOT="$root" \
            BUILD="$build" "$build/module-table-runtime.s"
        if [ "$root" = disk ] || [ "$root" = drum ]; then
                expected=0
        else
                expected=1
        fi
        grep -qx "\.set TAPE_FS_ENABLED,$expected" \
            "$build/module-table-runtime.s" || {
                echo "incorrect tape filesystem selection for ROOT=$root" >&2
                exit 1
            }
done

grep -q 'root_select_class() != KINIT_ROOT_DTC' \
    "$DAIMOS_REPO/system/kernel/modules/module_minit.c" || {
        echo 'missing DECtape-root runtime installation guard' >&2
        exit 1
    }

echo 'daimos-root-tapefs-selection-20261012-v1: PASS'
