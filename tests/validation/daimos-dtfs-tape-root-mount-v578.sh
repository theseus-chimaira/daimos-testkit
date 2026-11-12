#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-dtfs-tape-root-mount-v578
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/$tag-$$"
build=${DAIMOS_TSFS_PREBUILT_BUILD:-$work/build}
# v1491: the old separate host-tools `build` target was retired.  Use
# the installed production TSFS producer from the required PDP10_PREFIX;
# avoid building or linking an obsolete second producer into this test.
mktsfs="$PDP10_PREFIX/bin/mktsfs"
test -x "$mktsfs" || { echo "$tag: missing installed mktsfs" >&2; exit 1; }
pty="$work/pty-run"
tcp="$work/tcp-run"
cty_in="$work/cty.in"
dcs_in="$work/dcs.in"
cty_out="$work/cty.out"
dcs_out="$work/dcs.out"
simh_pid=
dcs_pid=
dcs_port=$((20000 + ($$ % 10000)))
ge_port=$((40000 + ($$ % 10000)))
tsfs_wait_ticks=${DAIMOS_TSFS_WAIT_TICKS:-2400}
tsfs_simh=${DAIMOS_TSFS_SIMH:-$PDP10_PREFIX/bin/pdp6}

cleanup()
{
        for pid in "$dcs_pid" "$simh_pid"; do
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                        kill "$pid" 2>/dev/null || true
                        wait "$pid" 2>/dev/null || true
                fi
        done
        exec 3>&- 4>&- 2>/dev/null || true
        if [ "${DAIMOS_TSFS_KEEP_WORK:-0}" != 1 ]; then
                rm -rf "$work"
        fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work/media"

"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"
"$host_cc" -std=c99 -O2 -Wall -Wextra -o "$tcp" \
        "$(dirname "$0")/../../tools/tcp-run-v1.c"

: >"$work/empty"
cat > "$work/manifest" <<EOF
D /SYSTEM
D /SYSTEM/EXEC
F /SYSTEM/EXEC/HELLO $work/empty
F /README $work/empty
D /DOC
F /DOC/INDEX $work/empty
EOF
"$mktsfs" -n 3 -i 1:2345 -g 7 \
        -m "$work/manifest" -o "$work/media/member" >/dev/null

# The v1524 negative-policy variant boots an independent D6FS root with
# ROOT=auto. DTFS/TSFS is LINKED but is NOT installed for a disk-selected
# root by minit: this variant tests physical MKFS/FSCK and mount refusal.
# The original v578 tape-root acceptance is unchanged otherwise.
if [ "${DAIMOS_DTFS_DISK_ROOT_V1524:-0}" = 1 ]; then
        build_root=auto
        build_boot=dsk
else
        build_root=tape
        build_boot=ptr
fi
if [ -z "${DAIMOS_TSFS_PREBUILT_BUILD:-}" ]; then
        PATH="$PDP10_PREFIX/bin:$PATH" \
                "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
                BUILD="$build" USERLAND_BUILD_ROOT="$build" \
                ROOT="$build_root" BOOT="$build_boot" \
                PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
                HOST_TOOLS="$PDP10_PREFIX/bin" \
                SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null
fi
# Add test-only directory records to the actual TSFS root media.  No
# secondary-mount command or retired MOUNT.TSFS binary is involved.
if [ "${DAIMOS_DTFS_DISK_ROOT_V1524:-0}" != 1 ]; then
cp "$build/tsfs-root.manifest" "$work/root-v577.manifest"
cat >> "$work/root-v577.manifest" <<EOF
D /DOC 0555 0 0
F /README $work/empty 0444 0 0
F /DOC/INDEX $work/empty 0444 0 0
F /SYSTEM/EXEC/HELLO $work/empty 0555 0 0
D /MOUNT/DT0 0755 0 0
EOF
"$mktsfs" -n 3 -i 1:1 -g 1 \
    -m "$work/root-v577.manifest" -o "$work/media/root-v577" >/dev/null
cp "$work/media/root-v5770.dta" "$build/media/dtc0.tap"
cp "$work/media/root-v5771.dta" "$build/media/dtc1.tap"
cp "$work/media/root-v5772.dta" "$build/media/dtc2.tap"
fi
if [ "${DAIMOS_TSFS_CHECK_MOUNT_CWD_BUSY:-0}" = 1 ]; then
        # V1523's physical lifecycle test needs a complete 578-block
        # DTC3 medium. A zero-byte simulator attachment has no DECtape
        # block marks and makes target MKFS search an absent geometry.
        # Prepare a complete physical transport image. The target MKFS
        # below performs the actual native filesystem formatting so
        # this test does not depend on host image-format compatibility.
        # Only the disposable test medium is replaced.
        test -x "$PDP10_PREFIX/bin/mkdtfs" || \
            fail_logs 'v1523: installed native mkdtfs is missing'
        rm -f "$build/media/dtc3.tap"
        "$PDP10_PREFIX/bin/mkdtfs" -o "$build/media/dtc3.tap" || \
            fail_logs 'v1523: could not prepare physical DTC3 geometry'
fi
"$self/../lib/daimos-simh-headless.sh" "$build/boot.ini" \
        "$build/boot.headless.ini" "$dcs_port" "$ge_port"
if [ "${DAIMOS_TSFS_DTC_DEBUG_V1524:-0}" = 1 ]; then
        # Diagnostic-only Type-551 trace. Set up before the bootstrap
        # GO command; a command appended after GO would never execute.
        python3 - "$build/boot.headless.ini" "$work/dtc-v1524.debug" <<'PY'
from pathlib import Path
import sys
ini, debug = (Path(value) for value in sys.argv[1:])
text = ini.read_text()
lines = text.splitlines(keepends=True)
assert sum(line.strip() == 'break 060' for line in lines) == 1
with ini.open('w') as output:
    for line in lines:
        if line.strip() == 'break 060':
            output.write('set debug ' + str(debug) + '\n')
            output.write('set DTC debug=DETAIL\n')
        output.write(line)
PY
fi

mkfifo "$cty_in" "$dcs_in"
exec 3<>"$cty_in"
exec 4<>"$dcs_in"
(
        cd "$build"
        TERM=dumb exec "$pty" -r "$tsfs_simh" \
                boot.headless.ini \
                <"$cty_in" >"$cty_out" 2>&1
) &
simh_pid=$!
"$tcp" 127.0.0.1 "$dcs_port" <"$dcs_in" >"$dcs_out" 2>&1 &
dcs_pid=$!

log_size()
{
        if [ -f "$1" ]; then wc -c <"$1" | tr -d ' '; else echo 0; fi
}

wait_new()
{
        file=$1
        pattern=$2
        start=$3
        ticks=${4:-$tsfs_wait_ticks}
        i=0
        while [ "$i" -lt "$ticks" ]; do
                if tail -c "+$((start + 1))" "$file" 2>/dev/null | \
                        grep -F "$pattern" >/dev/null 2>&1; then
                        return 0
                fi
                kill -0 "$simh_pid" 2>/dev/null || return 1
                sleep 0.1
                i=$((i + 1))
        done
        return 1
}

fail_logs()
{
        echo '--- CTY ---' >&2
        cat "$cty_out" >&2 || true
        echo '--- DCS0 ---' >&2
        cat "$dcs_out" >&2 || true
        echo "$tag: $1" >&2
        exit 1
}

send_slow()
{
        text=$1
        while [ -n "$text" ]; do
                rest=${text#?}
                ch=${text%"$rest"}
                printf '%s' "$ch" >&4
                sleep 0.08
                text=$rest
        done
        printf '\r' >&4
        sleep 0.15
}

wait_new "$dcs_out" 'Connected to the PDP6 simulator DCS device' 0 || \
        fail_logs 'DCS0 transport did not connect'
start=`log_size "$dcs_out"`
send_slow ''
wait_new "$dcs_out" 'LOGIN: ' "$start" || fail_logs 'DCS0 LOGIN did not reprompt'
start=`log_size "$dcs_out"`
send_slow ROOT
wait_new "$dcs_out" 'DSH V1' "$start" || fail_logs 'ROOT login did not enter DSH'

start=`log_size "$dcs_out"`
# With a DTC-selected root, DTFS MRES is installed.  Exercise a real
# native-format secondary DECtape rather than obsolete MOUNT.TSFS.
send_slow 'MKFS.DTFS -O NATIVE /DEV/DTC3'
wait_new "$dcs_out" '# ' "$start" || \
    fail_logs 'secondary DTFS format did not return'
start=`log_size "$dcs_out"`
send_slow 'FSCK.DTFS -O NATIVE /DEV/DTC3'
wait_new "$dcs_out" 'FSCK.DTFS NATIVE OK' "$start" || \
    fail_logs 'secondary native DTFS failed validation'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'secondary DTFS check did not return'
if tail -c "+$((start + 1))" "$dcs_out" | grep -F 'FSCK.DTFS:' >/dev/null; then
        fail_logs 'secondary FSCK returned a command error'
fi
start=`log_size "$dcs_out"`
send_slow 'MOUNT.DTFS /DEV/DTC3 /MOUNT/DT0'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'DTFS mount did not return'
if [ "${DAIMOS_EXPECT_DTFS_PROVIDER_REFUSAL_V1524:-0}" = 1 ]; then
        # Disk-selected auto-root does not install the DTFS MRES.
        # This is a negative-policy oracle, never a mount PASS.
        if ! tail -c "+$((start + 1))" "$dcs_out" |
            grep -F 'MOUNT.DTFS: /MOUNT/DT0' >/dev/null; then
                fail_logs 'missing expected disk-root DTFS MRES refusal'
        fi
        start=`log_size "$dcs_out"`
        send_slow 'MOUNT'
        wait_new "$dcs_out" '# ' "$start" ||
            fail_logs 'negative-control mount inventory did not return'
        if tail -c "+$((start + 1))" "$dcs_out" |
            grep -F 'MOUNT:' >/dev/null; then
                fail_logs 'negative-control FSINFO/MOUNT inventory failed'
        fi
        if tail -c "+$((start + 1))" "$dcs_out" |
            grep -F 'DTFS /MOUNT/DT0' >/dev/null; then
                fail_logs 'unexpected DTFS mount published in negative case'
        fi
        printf '%s\n' "$tag: PASS (disk root: physical MKFS/FSCK; DTFS MRES correctly absent)"
        exit 0
fi
if tail -c "+$((start + 1))" "$dcs_out" | grep -F 'MOUNT.DTFS:' >/dev/null; then
        fail_logs 'MOUNT.DTFS returned an actual error'
fi
start=`log_size "$dcs_out"`
send_slow 'MOUNT'
wait_new "$dcs_out" 'DTFS /MOUNT/DT0' "$start" ||
    fail_logs 'DTFS mount absent from FSINFO/MOUNT inventory'
wait_new "$dcs_out" '# ' "$start" ||
    fail_logs 'mounted DTFS inventory did not return'
if tail -c "+$((start + 1))" "$dcs_out" | grep -F 'MOUNT:' >/dev/null; then
        fail_logs 'mounted DTFS inventory returned a command error'
fi
start=`log_size "$dcs_out"`
send_slow 'STAT /MOUNT/DT0'
wait_new "$dcs_out" '/MOUNT/DT0 TYPE 1' "$start" || \
    fail_logs 'secondary native DTFS mount root stat failed'
if [ "${DAIMOS_TSFS_CHECK_MOUNT_CWD_BUSY:-0}" = 1 ]; then
        # V1523: the real DSH keeps cwd in its stable process u-area.
        # An external UNMOUNT child inherits that cwd; neither it nor
        # any other process may permit the live mount slot to be retired.
        start=`log_size "$dcs_out"`
        send_slow 'CD /MOUNT/DT0'
        wait_new "$dcs_out" '# ' "$start" || \
            fail_logs 'v1523 CD into mounted DTFS did not finish'
        start=`log_size "$dcs_out"`
        send_slow 'PWD'
        wait_new "$dcs_out" '/MOUNT/DT0' "$start" || \
            fail_logs 'v1523 shell cwd did not enter secondary DTFS'
        wait_new "$dcs_out" '# ' "$start" || \
            fail_logs 'v1523 shell cwd verification did not return'
        start=`log_size "$dcs_out"`
        send_slow 'UNMOUNT /MOUNT/DT0'
        wait_new "$dcs_out" 'UNMOUNT: /MOUNT/DT0' "$start" || \
            fail_logs 'v1523 unmount incorrectly retired a busy cwd mount'
        wait_new "$dcs_out" '# ' "$start" || \
            fail_logs 'v1523 busy UNMOUNT did not return'
        start=`log_size "$dcs_out"`
        send_slow 'CD /'
        wait_new "$dcs_out" '# ' "$start" || \
            fail_logs 'v1523 shell did not leave mounted DTFS'
fi
start=`log_size "$dcs_out"`
send_slow 'UNMOUNT /MOUNT/DT0'
wait_new "$dcs_out" '# ' "$start" || fail_logs 'secondary native DTFS unmount did not return'
if tail -c "+$((start + 1))" "$dcs_out" | grep -F 'UNMOUNT:' >/dev/null; then
        fail_logs 'final UNMOUNT command refused'
fi
start=`log_size "$dcs_out"`
send_slow 'MOUNT'
wait_new "$dcs_out" '# ' "$start" ||
    fail_logs 'post-unmount inventory did not return'
if tail -c "+$((start + 1))" "$dcs_out" | grep -F 'MOUNT:' >/dev/null; then
        fail_logs 'post-unmount FSINFO/MOUNT inventory failed'
fi
if tail -c "+$((start + 1))" "$dcs_out" | grep -F 'DTFS /MOUNT/DT0' >/dev/null; then
        fail_logs 'DTFS mount remained published after unmount'
fi
start=`log_size "$dcs_out"`
send_slow 'ECHO DTFSMOUNTOK'
wait_new "$dcs_out" DTFSMOUNTOK "$start" || fail_logs 'DSH did not resume after helper exit'

printf '%s\n' "$tag: PASS (tape-root installed DTFS MRES, secondary native mount/stat/unmount)"
