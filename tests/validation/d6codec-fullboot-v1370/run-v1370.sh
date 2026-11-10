#!/bin/sh
# Full isolated grouped D6CODEC PDP-6 boot and interactive RUN acceptance.
# No DAIMOS source, production image, or existing filesystem is modified.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to the staged DAIMOS checkout}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
repo=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
here="$testkit/tests/validation/d6codec-fullboot-v1370"
work="$TMPDIR/d6codec-fullboot-v1370"
linked="$TMPDIR/d6codec-kcore-link-v1368"
userland="$work/userland-build/userland"
config="$work/config-v1370"
programs="$work/grouped-userland-v1370"
mkdir -p "$work" "$config" "$programs"

logtail()
{
    tail -50 "$1" >&2 || :
}

printf '%s\n' 'V1370 PHASE 1: verify actual KCORE and grouped relocation map'
if ! DAIMOS_REPO="$repo" sh \
    "$testkit/tests/validation/d6codec-kcore-link-v1368/run-v1368.sh" \
    > "$work/kcore-link-v1370.log" 2>&1; then
    logtail "$work/kcore-link-v1370.log"
    exit 1
fi
tail -8 "$work/kcore-link-v1370.log"

printf '%s\n' 'V1370 PHASE 2: rebuild and relink all 27 MRES plus complete KINIT'
if ! python3 -B "$here/build_grouped_image_v1370.py" \
    "$repo" "$linked" "$work" > "$work/build-link-v1370.log" 2>&1; then
    logtail "$work/build-link-v1370.log"
    exit 1
fi
grep '^MRES_V1370_PASS' "$work/build-link-v1370.log" | tail -4
grep -E '^KINIT_(BASELINE|GROUPED)' "$work/build-link-v1370.log"
test "$(grep -c '^MRES_V1370_PASS' "$work/build-link-v1370.log")" -eq 27

printf '%s\n' 'V1370 PHASE 3: generate and validate complete grouped KINIT boot stream'
rm -f "$work/grouped-kinit-v1370.compressed.words"
python3 -B "$testkit/tests/validation/d6codec-kinit-image-v1365/make_grouped_kinit_v1365.py" \
    "$work/grouped-kinit-v1370.words" \
    "$work/grouped-kinit-v1370.compressed.words" 01000000 0400
python3 -B "$testkit/tests/validation/d6codec-stage1-geometry-v1364/generate-v1364.py" \
    "$repo" "$testkit" "$work/stage1-v1370" 01000000 0400 \
    > "$work/stage1-gen-v1370.log"
das -F -K -L "$work/stage1-dtc-v1370.labels" \
    -O "$work/stage1-dtc-v1370.dxr" "$work/stage1-v1370/stage1-dtc-v1364.s"
dxrconvert --pdp6-readin -b 060 "$work/stage1-dtc-v1370.dxr" \
    "$work/stage1-dtc-v1370.pt"
mkdt -t dtc -p "$work/grouped-kinit-v1370.compressed.words" \
    -o "$work/grouped-kinit-v1370.dta"

printf '%s\n' 'V1370 PHASE 4: build PDP-6 userland and produce grouped DXR2 programs'
if ! make -s -C "$repo/userland" build COMPILER=kcc \
    BUILD_ROOT="$work/userland-build" PDP10_PREFIX="$PDP10_PREFIX" \
    > "$work/userland-build-v1370.log" 2>&1; then
    logtail "$work/userland-build-v1370.log"
    exit 1
fi
for entry in login dsh program/ECHO; do
    filename=$(basename "$entry")
    output="$programs/$filename.grouped-v1370.dxr"
    rm -f "$output"
    python3 -B "$testkit/tests/validation/d6codec-runtime-exec-v1369/grouped_dxr_v1369.py" \
        "$userland/$entry.dxr" "$output"
done
for spec in INITTAB:inittab FSTAB:fstab PASSWD:passwd SYSTEM:system; do
    label=${spec%%:*}
    name=${spec#*:}
    s6text --encode "$repo/userland/config/$name" "$config/$label.s6rec"
done

printf '%s\n' 'V1370 PHASE 5: build pristine D6FS root with grouped LOGIN/DSH/ECHO'
base="$work/disk-pristine-v1370"
mkdir -p "$base"
mkdsk -n 4 -m clean -p "$work/grouped-kinit-v1370.compressed.words" \
    -o "$base" --d6fs-layout --logstore-blocks 0400 \
    --swap-tail-blocks 0400 --spare-blocks 0 \
    --member-sectors 0130000,0130000,0130000,0130000
mkd6fs -n 4 -d "$base" \
    -D /TEMP:0777 -D /SCRATCH:0777 -D /SYSTEM:0555 \
    -D /SYSTEM/EXEC:0555 -D /CONFIG:0755 \
    -f "/SYSTEM/INIT:$userland/init.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/MOUNTALL:$userland/mountall.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/LOGIN:$programs/login.grouped-v1370.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/DSH:$programs/dsh.grouped-v1370.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/ECHO:$programs/ECHO.grouped-v1370.dxr:555:dxr" \
    -f "/CONFIG/INITTAB:$config/INITTAB.s6rec:644:binwords" \
    -f "/CONFIG/FSTAB:$config/FSTAB.s6rec:644:binwords" \
    -f "/CONFIG/PASSWD:$config/PASSWD.s6rec:600:binwords" \
    -f "/CONFIG/SYSTEM:$config/SYSTEM.s6rec:644:binwords"
logstore -n 4 -d "$base" --init
d6fsck -n 4 -d "$base"

# A boot can leave a newer DIRTY superblock, even after a failed
# attempt. Always clone a CLEAN base independently for each control.
clone_disks()
{
    destination="$work/disk-$1-v1370"
    mkdir -p "$destination"
    for i in 0 1 2 3; do
        cp "$base/dsk$i.dsk" "$destination/dsk$i.dsk"
    done
}

# Exercise a real Type-760 read-in and DECtape Stage-1. The optional
# graphical/consoles are disabled for reliable headless SIMH operation.
make_simh()
{
    destination="$1"
    tape="$2"
    disk="$3"
    cat > "$destination" <<EOF
set cpu 256k
deposit SW 1
set pclk enabled
set pclk REALTIME
set cr enabled
set cp enabled
set ptr enabled
set ptp enabled
set lpt enabled
set dsk enabled
set dp enabled
set dr enabled
set dr0 enabled
set dr1 enabled
set dr2 enabled
set dr3 enabled
set dct enabled
set dtc dct=04
set dtc enabled
set dtc0 enabled
set dtc1 enabled
set dtc2 enabled
set dtc3 enabled
set mtc dct=0
set mtc enabled
set mtc0 enabled
set mtc0 7t
set mtc1 enabled
set mtc1 7t
set dcs enabled
set dcs lines=8
set ge enabled
set ge ascii
set slave enabled
set dpy disabled
set wcnsls disabled
set ocnsls disabled
deposit 020 710600000060
deposit 021 710740000010
deposit 022 254000000021
deposit 023 710440000026
deposit 024 710740000010
deposit 025 254000000024
deposit 026 000000000000
deposit 027 254000000021
attach -q ptr $work/stage1-dtc-v1370.pt
deposit ptr time 1
attach -q dtc0 $tape
attach -q dsk0 $disk/dsk0.dsk
attach -q dsk1 $disk/dsk1.dsk
attach -q dsk2 $disk/dsk2.dsk
attach -q dsk3 $disk/dsk3.dsk
go 020
exit
EOF
}

printf '%s\n' 'V1370 PHASE 6: independent D6LZ36 kernel negative-format control'
clone_disks control
rm -f "$work/control-kinit-grouped-v1370.words"
python3 -B "$testkit/tests/validation/d6codec-kinit-image-v1365/make_grouped_kinit_v1365.py" \
    "$repo/build/system/boot/pdp6/kinit.words" \
    "$work/control-kinit-grouped-v1370.words" 01000000 0400
mkdt -t dtc -p "$work/control-kinit-grouped-v1370.words" \
    -o "$work/control-kinit-grouped-v1370.dta"
make_simh "$work/boot-control-v1370.simh" \
    "$work/control-kinit-grouped-v1370.dta" "$work/disk-control-v1370"
# The control has no grouped runtime and must fail to RUN grouped LOGIN.
# SIMH stays inside INIT's retry loop; timeout is expected here.
control_status=0
TERM=dumb timeout -k 2s 35s "$PDP10_PREFIX/bin/pdp6" \
    "$work/boot-control-v1370.simh" </dev/null \
    > "$work/boot-control-v1370.out" 2>&1 || control_status=$?
if ! grep -F 'INIT V1' "$work/boot-control-v1370.out" >/dev/null ||
   ! grep -F 'INIT: RUN FAILED' "$work/boot-control-v1370.out" >/dev/null ||
   grep -F 'LOGIN: ' "$work/boot-control-v1370.out" >/dev/null; then
    echo "v1370: control invalid (simulator status $control_status)" >&2
    logtail "$work/boot-control-v1370.out"
    exit 1
fi
echo 'CONTROL_V1370_PASS original D6LZ36 KCORE cannot RUN grouped LOGIN'

printf '%s\n' 'V1370 PHASE 7: real grouped cold boot and interactive shell RUN'
clone_disks grouped
make_simh "$work/boot-grouped-v1370.simh" \
    "$work/grouped-kinit-v1370.dta" "$work/disk-grouped-v1370"
cc -std=c99 -O2 -Wall -Wextra -o "$work/pty-run-v1370" \
    "$testkit/tools/pty-run-v1.c"

fifo="$work/simh-input-v1370.fifo"
out="$work/boot-interactive-v1370.out"
rm -f "$fifo"
mkfifo "$fifo"
child=
cleanup()
{
    if [ -n "$child" ] && kill -0 "$child" 2>/dev/null; then
        kill "$child" 2>/dev/null || :
        wait "$child" 2>/dev/null || :
    fi
    exec 3>&- 2>/dev/null || :
    rm -f "$fifo"
}
trap cleanup EXIT HUP INT TERM
exec 3<>"$fifo"
(
    TERM=dumb exec "$work/pty-run-v1370" -r "$PDP10_PREFIX/bin/pdp6" \
        "$work/boot-grouped-v1370.simh" <"$fifo" >"$out" 2>&1
) &
child=$!

bytes()
{
    if [ -f "$out" ]; then wc -c < "$out" | tr -d ' '; else echo 0; fi
}
wait_new()
{
    wanted=$1
    offset=$2
    limit=${3:-1000}
    i=0
    while [ "$i" -lt "$limit" ]; do
        if tail -c "+$((offset + 1))" "$out" 2>/dev/null |
            grep -F "$wanted" >/dev/null 2>&1; then
            return 0
        fi
        if ! kill -0 "$child" 2>/dev/null; then
            echo "v1370: simulator terminated before $wanted" >&2
            logtail "$out"
            return 1
        fi
        sleep .1
        i=$((i + 1))
    done
    echo "v1370: timeout before $wanted" >&2
    logtail "$out"
    return 1
}

wait_new 'LOGIN: ' 0
echo 'BOOT_GROUPED_LOGIN_V1370_PASS INIT->LOGIN'
start=$(bytes)
sleep .3
for ch in R O O T; do
    printf '%s' "$ch" >&3
    sleep .05
done
printf '\r' >&3
wait_new '# ' "$start"
echo 'BOOT_GROUPED_SHELL_V1370_PASS LOGIN->DSH'
start=$(bytes)
printf 'ECHO V1370GROUPED\r' >&3
wait_new '# ' "$start"

# An echoed command-line is not proof that ECHO executed. Require the
# standalone output line and the following interactive prompt.
python3 - "$out" <<'PY'
from pathlib import Path
import re
import sys
raw = Path(sys.argv[1]).read_bytes()
if not re.search(rb'(?:\r\n|\n)V1370GROUPED\r?\n# ', raw):
    raise SystemExit('v1370: grouped ECHO produced no standalone output line')
print('BOOT_GROUPED_RUN_V1370_PASS real DSH RUN -> grouped ECHO output')
PY

start=$(bytes)
printf 'exit\r' >&3
wait_new 'LOGIN: ' "$start"
echo 'BOOT_GROUPED_RESPAWN_V1370_PASS DSH exit -> INIT LOGIN respawn'
if grep -E 'INIT: RUN FAILED|\?RT|HALT instruction' "$out" >/dev/null; then
    echo 'v1370: guest reported a boot or RUN failure' >&2
    logtail "$out"
    exit 1
fi

printf '%s\n' 'PASS v1370 full grouped cold boot: 27 MRES, KINIT, real D6FS, INIT, grouped LOGIN, DSH, ECHO and respawn'
