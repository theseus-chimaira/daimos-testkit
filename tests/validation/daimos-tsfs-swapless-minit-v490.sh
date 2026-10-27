#!/bin/sh
# Verify lowmem tape bootstrap does not install SWAP while disk still does.
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
        awk '/^proc_swap_minit_v481:/{getline; if ($1 != "popj" || $2 != "17,") exit 1; ok=1} END {if (!ok) exit 1}' \
            "$build/module_minit.s" || {
                echo 'swapless TSFS entry must return without installation' >&2; exit 1;
            }
    else
        grep -q 'proc_swap_minit_v481:' "$build/module_minit.s"
    fi
done
echo 'daimos-tsfs-swapless-minit-v490: PASS'
