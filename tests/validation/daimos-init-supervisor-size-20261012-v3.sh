#!/bin/sh
# Verify the split PID-1 executable sizes in an actual PDP-6 DXR build.
set -eu
: "${INIT_DXR:?set INIT_DXR to the startup INIT executable}"
: "${SUPERVISOR_DXR:?set SUPERVISOR_DXR to the resident PID 1 executable}"
: "${DSH_DXR:?set DSH_DXR to the shell executable}"
: "${DXRCHECK:=dxrcheck}"

check_image()
{
    path=$1
    limit=$2
    label=$3
    record=$("$DXRCHECK" "$path")
    image=$(printf '%s\n' "$record" | sed -n 's/^DXR image=\([0-7][0-7]*\).*/\1/p')
    bss=$(printf '%s\n' "$record" | sed -n 's/^DXR image=[0-7][0-7]* bss=\([0-7][0-7]*\).*/\1/p')
    if test -z "$image" || test -z "$bss"; then
        echo "FAIL $label: missing DXR image/BSS" >&2
        return 1
    fi
    if test $((0$image)) -gt $((0$limit)); then
        echo "FAIL $label: $image octal image exceeds $limit" >&2
        return 1
    fi
    resident=$((0$image + 0$bss + 02020))
    rounded=$(((resident + 01777) & ~01777))
    printf 'PASS %s: image=%s bss=%s VM=%o octal\n' "$label" "$image" "$bss" "$rounded"
}

check_image "$INIT_DXR" 004210 INIT
check_image "$SUPERVISOR_DXR" 001447 SUPERVISOR
check_image "$DSH_DXR" 036000 DSH

# Startup code is discarded by SYS_EXEC; PID 1 must require at most
# 006000 octal resident VM words with 02000 stack + 020 origin.
record=$("$DXRCHECK" "$SUPERVISOR_DXR")
image=$(printf '%s\n' "$record" | sed -n 's/^DXR image=\([0-7][0-7]*\).*/\1/p')
bss=$(printf '%s\n' "$record" | sed -n 's/^DXR image=[0-7][0-7]* bss=\([0-7][0-7]*\).*/\1/p')
total=$((0$image + 0$bss + 02020))
if test $(((total + 01777) & ~01777)) -gt $((006000)); then
    echo 'FAIL: resident PID 1 requires more than 006000 octal words' >&2
    exit 1
fi
echo 'PASS: supervisor text below 02000 and PID 1 VM no larger than 006000 octal'
