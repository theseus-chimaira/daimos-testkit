#!/bin/sh
# Build and measure 32K disk/tape kernel+KINIT profiles without userland,
# a filesystem image, shell startup or simulator execution.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to the DAIMOS checkout}"
: "${PDP10_PREFIX:?set PDP10_PREFIX to the PDP-10 tool prefix}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-vfs-32k-footprint-v13.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

map_symbol()
{
    awk -v symbol="$2" '$1 == symbol { print $2; found++ }
        END { if (found != 1) exit 1 }' "$1"
}

for root in disk tape; do
    case "$root" in
        disk) boot=dsk ;;
        tape) boot=dtc ;;
    esac
    build="$work/$root"
    out="$build/system/boot/pdp6"
    if ! make -C "$DAIMOS_REPO/system/boot/pdp6" permanent-size \
        "$out/kinit.lowmem.words" BOOT_PROFILE=lowmem COMPILER=gcc \
        ROOT="$root" BOOT="$boot" BUILD_ROOT="$build" \
        PDP10_PREFIX="$PDP10_PREFIX" >"$work/$root.log" 2>&1; then
        tail -40 "$work/$root.log" >&2
        exit 1
    fi

    end=$(map_symbol "$out/kcore.map" __kcore_low_end)
    image_end=$(map_symbol "$out/kinit.map" __kinit_image_end)
    case "$end:$image_end" in
        *[!0-7:]*|'') echo "invalid octal link-map values" >&2; exit 1 ;;
    esac
    kcore_end=$((0$end))
    image_last=$((0$image_end))
    lowmem_stack=02000
    core_words=0100000
    stack_last=$((image_last + lowmem_stack))
    [ "$stack_last" -lt "$core_words" ] || {
        echo "$root: KINIT plus stack exceeds 32K core" >&2
        exit 1
    }
    stream_words=$(wc -l < "$out/kinit.lowmem.words" | tr -d ' ')
    if [ "$kcore_end" -ge $((020000)) ]; then
        gate="FAIL (+$((kcore_end - 020000)) words)"
    else
        gate=PASS
    fi
    printf '%s: KCORE_END=%s 32K_KCORE_GATE=%s KINIT_END=%s FREE_AFTER_STACK=%d BOOT_STREAM_WORDS=%s\n' \
        "$root" "$end" "$gate" "$image_end" \
        "$((core_words - stack_last))" "$stream_words"
done

echo 'vfs-32k-footprint-v13: measurement complete (no shell or boot acceptance claimed)'
