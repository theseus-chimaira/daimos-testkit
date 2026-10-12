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
    case "$label" in
        SUPERVISOR) reserve=0400 ;;
        *) reserve=02000 ;;
    esac
    resident=$((0$image + 0$bss + 020 + reserve))
    rounded=$(((resident + 01777) & ~01777))
    printf 'PASS %s: image=%s bss=%s VM=%o octal\n' "$label" "$image" "$bss" "$rounded"
}

check_image "$INIT_DXR" 004210 INIT
check_image "$SUPERVISOR_DXR" 001177 SUPERVISOR
check_image "$DSH_DXR" 036000 DSH

# Verify the new DXR2 ST2 stack metadata rather than trusting a build flag.
python3 - "$SUPERVISOR_DXR" <<'PYTEST'
import sys
from pathlib import Path
raw = Path(sys.argv[1]).read_bytes()
if len(raw) < 24:
    raise SystemExit('FAIL: supervisor DXR header truncated')
w = int.from_bytes(raw[16:24], 'little')
if (w & 0o777777) != 0o636422 or (w >> 18) != 0o400:
    raise SystemExit('FAIL: supervisor ST2 metadata is not 0400')
print('PASS: supervisor DXR2 ST2 stack metadata 0400')
PYTEST
record=$("$DXRCHECK" "$SUPERVISOR_DXR")
image=$(printf '%s\n' "$record" | sed -n 's/^DXR image=\([0-7][0-7]*\).*/\1/p')
bss=$(printf '%s\n' "$record" | sed -n 's/^DXR image=[0-7][0-7]* bss=\([0-7][0-7]*\).*/\1/p')
total=$((0$image + 0$bss + 020 + 0400))
if test $(((total + 01777) & ~01777)) -ne $((02000)); then
    echo 'FAIL: resident PID 1 does not fit exactly one APR block' >&2
    exit 1
fi
echo 'PASS: resident PID 1 requires a single 02000-word APR allocation'
