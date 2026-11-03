#!/bin/sh
# The MonitorFS swapped-reader is a deliberate GCC leaf with a fixed
# assembly ABI. It must stay GCC-built even when the main kernel uses KCC:
# the linked GCC MRES package is 125 PDP-6 words smaller than KCC's.
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:=$HOME/tmp}"

work="$TMPDIR/daimos-monitorfs-compiler-v1033-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

for compiler in kcc gcc; do
        build="$work/$compiler"
        object="$build/monitorfs_swap_v63_mres.dobj"
        log="$work/$compiler.log"
        # The invocation trace is part of this test's contract: ignore an
        # outer `make -s` while inspecting the actual selected compiler.
        if ! env -u MAKEFLAGS -u MFLAGS make \
            -C "$DAIMOS_REPO/system/boot/pdp6" "$object" \
            BUILD="$build" COMPILER="$compiler" \
            PDP10_PREFIX="$PDP10_PREFIX" \
            PDP10_KCC="$PDP10_PREFIX/bin/kcc" \
            PDP10_GCC="$PDP10_PREFIX/bin/pdp10-dec-none-gcc" \
            DAS="$PDP10_PREFIX/bin/das" > "$log" 2>&1; then
                cat "$log" >&2
                echo "FAIL: MonitorFS $compiler compilation" >&2
                exit 1
        fi
        test -s "$object" || {
                echo "FAIL: missing MonitorFS $compiler object" >&2
                exit 1
        }
        grep -F "$PDP10_PREFIX/bin/pdp10-dec-none-gcc -std=gnu99" \
            "$log" >/dev/null
        if grep -i 'warning:' "$log" >/dev/null; then
                cat "$log" >&2
                echo "FAIL: MonitorFS $compiler emitted warnings" >&2
                exit 1
        fi
        if [ "$compiler" = kcc ]; then
                cp "$object" "$work/gcc-leaf-in-kcc-build.dobj"
        else
                cmp "$object" "$work/gcc-leaf-in-kcc-build.dobj"
        fi
        echo "PASS: MonitorFS GCC leaf in $compiler kernel build"
done
