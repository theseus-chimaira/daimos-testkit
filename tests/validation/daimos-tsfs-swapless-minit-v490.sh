#!/bin/sh
# Verify TSFS SWAP MINIT gates installation on validated AUXST1 backing.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
mkdir -p "$TMPDIR"
for root in tape disk; do
    build="$TMPDIR/daimos-v490-minit-$root-$$"
    if [ "$root" = tape ]; then d6fs=0; else d6fs=1; fi
    PATH="$PDP10_PREFIX/bin:$PATH" make -s -C \
        "$DAIMOS_REPO/system/kernel" \
        KINIT_FULL=0 KINIT_TAPE_BOOT="$((1-d6fs))" \
        D6FS_FS_ENABLED="$d6fs" COMPILER=gcc \
        BUILD="$build" "$build/module_minit.s" >/dev/null
    test -s "$build/module_minit.s"
    # This is the compiled KINIT implementation, not a source-text guard.
    if [ "$root" = tape ]; then
        awk '/^proc_swap_minit_v481:/{active=1} active && /^minit_register:/{exit} active {print}' \
            "$build/module_minit.s" > "$build/swap-minit.txt"
        grep -q 'auxstore_boot_discover' "$build/swap-minit.txt" || {
            echo 'TSFS swap selection does not discover AUXSTORE' >&2; exit 1;
        }
        grep -q 'auxstore_backstore_blocks' "$build/swap-minit.txt" || {
            echo 'TSFS swap selection does not require backing capacity' >&2; exit 1;
        }
        grep -q 'minit_install' "$build/swap-minit.txt" || {
            echo 'TSFS with valid backing cannot install SWAP' >&2; exit 1;
        }
    else
        grep -q 'proc_swap_minit_v481:' "$build/module_minit.s"
    fi
done
echo 'daimos-tsfs-swapless-minit-v490: PASS'
