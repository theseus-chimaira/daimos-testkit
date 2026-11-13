#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
host_cc=${HOST_CC:-cc}
tag=daimos-dtfs-tape-root-mount-v578
if [ "${DAIMOS_TSFS_MOUNT_PREFORMATTED_V1525:-0}" = 1 ] ||
    [ "${DAIMOS_TSFS_GATE_RUN_V1525:-0}" = 1 ]; then
        tag=daimos-dtfs-secondary-mounted-v1525
fi
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/$tag-$$"
build=${DAIMOS_TSFS_PREBUILT_BUILD:-$work/build}
# v1530: every physical runner owns its writable DTFS/TSFS tapes and
# generated SIMH command file. A reused KCC build is an immutable input:
# writing its media or boot.headless.ini lets overlapping test processes
# damage each other's physical evidence and produce false failures.
dtc3_media_v1530="$work/media/dtc3-v1530.tap"
dtc4_media_v1530="$work/media/dtc4-v1530.tap"
headless_ini_v1530="$work/boot-headless-v1530.ini"
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
if [ "${DAIMOS_TSFS_MINIMAL_ROOT_V1525:-0}" = 1 ]; then
        # This guest validates the installed DTFS provider, not all
        # optional userland programs. A complete image spreads DTC0
        # program extents over many blocks and creates long unnecessary
        # root-tape seeks for each MOUNT/STAT/UNMOUNT command.
        # Preserve actual INIT/LOGIN/DSH startup and every executable
        # needed for this physical test; remove unrelated programs
        # only from the disposable *test* TSFS image.
        python3 - "$work/root-v577.manifest" <<'PY'
from pathlib import Path
import os
import sys

manifest = Path(sys.argv[1])
needed = {
    '/SYSTEM/INIT',
    '/SYSTEM/EXEC/MOUNTALL',
    '/CONFIG/FSTAB',
    '/CONFIG/INITTAB',
    '/SYSTEM/EXEC/LOGIN',
    '/CONFIG/PASSWD',
    '/CONFIG/SYSTEM',
    '/SYSTEM/EXEC/DSH',
    '/SYSTEM/EXEC/ECHO',
    '/SYSTEM/EXEC/PWD',
    '/SYSTEM/EXEC/STAT',
    '/SYSTEM/EXEC/MOUNT',
    '/SYSTEM/EXEC/MOUNT.DTFS',
    '/SYSTEM/EXEC/UNMOUNT',
    '/SYSTEM/EXEC/DTFSPROBE',
}
if os.environ.get('DAIMOS_TSFS_GATE_RUN_V1525') == '1':
    # One test executable calls the real KCORE mount/FSINFO/chdir/unmount
    # services, so the disposable TSFS root needs only boot programs.
    needed.intersection_update({
        '/SYSTEM/INIT', '/SYSTEM/EXEC/MOUNTALL',
        '/CONFIG/FSTAB', '/CONFIG/INITTAB',
        '/SYSTEM/EXEC/LOGIN', '/CONFIG/PASSWD',
        '/CONFIG/SYSTEM', '/SYSTEM/EXEC/DSH',
    })
if os.environ.get('DAIMOS_TSFS_GATE_INIT_V1525') == '1':
    # A real booted KCORE starts this one-shot gate directly as INIT.
    # No shell or other userland executor is required for the syscall
    # lifecycle; this keeps primary root-tape I/O bounded.
    needed.intersection_update({'/SYSTEM/INIT'})
lines = manifest.read_text().splitlines()
existing = {line.split()[1] for line in lines if line.startswith('F ')}
assert needed <= existing, 'test root missing required executable'
chosen = [line for line in lines if line.startswith('D ') or
          (line.startswith('F ') and line.split()[1] in needed)]
assert len(chosen) < len(lines), 'test root not reduced'
if os.environ.get('DAIMOS_TSFS_GATE_INIT_V1525') == '1':
    binary = os.environ['DAIMOS_TSFS_GATE_DXR_V1525']
    assert Path(binary).is_file()
    chosen = [
        ' '.join([line.split()[0], line.split()[1], binary] +
                 line.split()[3:]) if line.startswith('F /SYSTEM/INIT ')
        else line for line in chosen
    ]
manifest.write_text('\n'.join(chosen) + '\n')
PY
fi
cat >> "$work/root-v577.manifest" <<EOF
D /DOC 0555 0 0
F /README $work/empty 0444 0 0
F /DOC/INDEX $work/empty 0444 0 0
F /SYSTEM/EXEC/HELLO $work/empty 0555 0 0
D /MOUNT/DT0 0755 0 0
EOF
if [ "${DAIMOS_TSFS_GATE_MEDIA_V1527:-0}" = 1 ]; then
        # The second independently stamped DTFS forces the real shared
        # mounted-directory loader away from DTC3 on demand. The test can
        # then require a genuine uncached physical DTC3 read after detach.
        printf 'D /MOUNT/DT1 0755 0 0\n' >> "$work/root-v577.manifest"
fi
if [ "${DAIMOS_TSFS_GATE_RUN_V1525:-0}" = 1 ]; then
        : "${DAIMOS_TSFS_GATE_BINARY_V1525:?compiled target test required}"
        test -f "$DAIMOS_TSFS_GATE_BINARY_V1525" || exit 1
        printf 'F /SYSTEM/EXEC/DTFSGATE %s 0555 0 0\n' \
            "$DAIMOS_TSFS_GATE_BINARY_V1525" >> "$work/root-v577.manifest"
fi
"$mktsfs" -n 3 -i 1:1 -g 1 \
    -m "$work/root-v577.manifest" -o "$work/media/root-v577" >/dev/null
cp "$work/media/root-v5770.dta" "$work/media/dtc0-v1530.tap"
cp "$work/media/root-v5771.dta" "$work/media/dtc1-v1530.tap"
cp "$work/media/root-v5772.dta" "$work/media/dtc2-v1530.tap"
fi
# The disk-root variant does not rebuild TSFS tapes. Copy every remaining
# boot-attached unit as well, so even that variant cannot mutate a prebuilt
# input image. An absent DTC3 file was historically a blank attachment.
for unit_v1530 in 0 1 2 3; do
        local_media_v1530="$work/media/dtc$unit_v1530-v1530.tap"
        if [ ! -e "$local_media_v1530" ]; then
                if [ -f "$build/media/dtc$unit_v1530.tap" ]; then
                        cp "$build/media/dtc$unit_v1530.tap" \
                            "$local_media_v1530"
                else
                        : > "$local_media_v1530"
                fi
        fi
done
if [ "${DAIMOS_TSFS_CHECK_MOUNT_CWD_BUSY:-0}" = 1 ] ||
    [ "${DAIMOS_TSFS_GATE_INIT_V1525:-0}" = 1 ] ||
    [ "${DAIMOS_TSFS_GATE_RUN_V1525:-0}" = 1 ] ||
    [ "${DAIMOS_TSFS_MOUNT_PREFORMATTED_V1525:-0}" = 1 ]; then
        # V1523's physical lifecycle test needs a complete 578-block
        # DTC3 medium. A zero-byte simulator attachment has no DECtape
        # block marks and makes target MKFS search an absent geometry.
        # The v1525 acceptance variant starts with the production
        # host-formatted native DTFS image, including the actual 72-bit
        # volume ID and RBN0144 directory. Its successful mount still
        # requires actual physical Type-551 reads and KCORE validation.
        # This avoids repeated DTC0 root EXECs for target MKFS/FSCK and
        # concentrates the DTC-root guest on *mounted* DTFS behavior.
        # The original v578/v1523 variant retains target MKFS/FSCK.
        # Only the disposable test medium is replaced.
        test -x "$PDP10_PREFIX/bin/mkdtfs" || \
            fail_logs 'v1523: installed native mkdtfs is missing'
        rm -f "$dtc3_media_v1530"
        "$PDP10_PREFIX/bin/mkdtfs" -o "$dtc3_media_v1530" || \
            fail_logs 'v1523: could not prepare physical DTC3 geometry'
        if [ "${DAIMOS_TSFS_GATE_MEDIA_V1527:-0}" = 1 ]; then
                rm -f "$dtc4_media_v1530"
                "$PDP10_PREFIX/bin/mkdtfs" -o "$dtc4_media_v1530" ||
                    { echo 'v1527: cannot build second DTFS' >&2; exit 1; }
                "$PDP10_PREFIX/bin/mkdtfs" \
                    -o "$work/media/replacement-v1527.tap" ||
                    { echo 'v1527: cannot build replacement DTFS' >&2; exit 1; }
                python3 - "$dtc3_media_v1530" \
                    "$dtc4_media_v1530" \
                    "$work/media/replacement-v1527.tap" <<'PY'
import struct
import sys

ids = []
for filename in sys.argv[1:]:
    with open(filename, 'rb') as stream:
        words = []
        for unused in range(4):
            high, low = struct.unpack('<II', stream.read(8))
            words.append(((high & 0o777777) << 18) |
                         (low & 0o777777))
    assert words[0] == 0o446466575421
    assert words[1] != 0 and words[2] != 0
    assert words[3] == (~(words[0] ^ words[1] ^ words[2]) &
                        0o777777777777)
    ids.append((words[1], words[2]))
assert len(set(ids)) == len(ids), 'distinct media identities required'
print('PASS v1527: three genuine distinct 72-bit DTFS identities')
PY
        fi
        if [ "${DAIMOS_TSFS_GATE_RUN_V1525:-0}" = 1 ]; then
                # The native host tool used during the older v1524 test
                # installation did not yet write the v1520 72-bit stamp.
                # Reject that stale tool and any host/target owner-map
                # disagreement *before* claiming a physical mount test.
                python3 - "$dtc3_media_v1530" <<'PY'
import struct
import sys
from pathlib import Path

image = Path(sys.argv[1])
with image.open('rb') as stream:
    def read_word():
        a, b = struct.unpack('<II', stream.read(8))
        return ((a & 0o777777) << 18) | (b & 0o777777)
    identity = [read_word() for _ in range(4)]
    assert identity[0] == 0o446466575421, 'missing DTVOL1 marker'
    assert identity[1] and identity[2], 'zero 72-bit identity half'
    assert identity[3] == (
        ~(identity[0] ^ identity[1] ^ identity[2]) &
        0o777777777777), 'invalid identity complement'
    stream.seek(0o144 * 128 * 8 + 12 * 8)
    assert read_word() == 0, 'native owner map word 12 unexpectedly used'
    assert (read_word() >> 21) & 0o37 == 0, (
        'native directory word 13 unexpectedly owns RBN 0144')
    assert (read_word() >> 21) & 0o37 == 0o36, (
        'native directory word 14 must reserve physical RBN 0144')
print('PASS v1525: stamped 72-bit native DTC3 and C dir[14]=ASM +016')
PY
        fi
fi
"$self/../lib/daimos-simh-headless.sh" "$build/boot.ini" \
        "$headless_ini_v1530" "$dcs_port" "$ge_port"
# The boot configuration generated by the *build* is immutable; redirect
# just the four native tape attachments to this run's private images.
# Keep all existing DSK/DRM/MTC/terminal setup and boot instructions.
python3 - "$headless_ini_v1530" "$build/media" "$work/media" <<'PY'
from pathlib import Path
import sys

ini = Path(sys.argv[1])
build_media = Path(sys.argv[2])
run_media = Path(sys.argv[3])
text = ini.read_text()
for unit in range(4):
    original = str(build_media / ("dtc%d.tap" % unit))
    isolated = str(run_media / ("dtc%d-v1530.tap" % unit))
    assert text.count(original) == 1, (unit, original, text.count(original))
    text = text.replace(original, isolated)
ini.write_text(text)
PY
if [ "${DAIMOS_TSFS_GATE_MEDIA_V1527:-0}" = 1 ] ||
    [ "${DAIMOS_TSFS_GATE_WRITE_V1528:-0}" = 1 ] ||
    [ "${DAIMOS_TSFS_GATE_PARTIAL_V1529:-0}" = 1 ]; then
        # The real Type-551 emulator supports eight physical transports.
        # All additional changes are to this disposable SIMH do-file,
        # not to the kernel or permanent boot root.
        python3 - "$headless_ini_v1530" \
            "$dtc4_media_v1530" <<'PY'
from pathlib import Path
import os
import sys

ini, dtc4 = (Path(s) for s in sys.argv[1:])
text = ini.read_text()
lines = text.splitlines(keepends=True)
assert sum(line.strip() == 'break 060' for line in lines) == 1
with ini.open('w') as output:
    for line in lines:
        if line.strip() == 'break 060' and \
                os.environ.get('DAIMOS_TSFS_GATE_MEDIA_V1527') == '1':
            output.write('set DTC4 enabled\n')
            output.write('attach -q DTC4 ' + str(dtc4) + '\n')
        output.write(line)
    # This special physical hot-swap test must return from GO 060 to
    # SIMH's interactive monitor when CTY sends Control-E. Ordinary
    # batch boot scripts deliberately end in EXIT, which otherwise
    # terminates the entire simulator instead of offering 'sim> '.
    # The file tail is rewritten below so the last EXIT is omitted.
final = ini.read_text().splitlines()
assert final[-1].strip() == 'exit'
ini.write_text('\n'.join(final[:-1]) + '\n')
PY
fi
if [ "${DAIMOS_TSFS_DTC_DEBUG_V1524:-0}" = 1 ] ||
    [ "${DAIMOS_TSFS_DTC_CONO_V1525:-0}" = 1 ]; then
        # Diagnostic-only Type-551 trace. Set up before the bootstrap
        # GO command; a command appended after GO would never execute.
        python3 - "$headless_ini_v1530" "$work/dtc-v1524.debug" <<'PY'
from pathlib import Path
import os
import sys
ini, debug = (Path(value) for value in sys.argv[1:])
text = ini.read_text()
lines = text.splitlines(keepends=True)
assert sum(line.strip() == 'break 060' for line in lines) == 1
with ini.open('w') as output:
    for line in lines:
        if line.strip() == 'break 060':
            output.write('set debug ' + str(debug) + '\n')
            if os.environ.get('DAIMOS_TSFS_DTC_CONO_V1525') == '1':
                output.write('set DTC debug=CONO\n')
            else:
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
                "$headless_ini_v1530" \
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
                if { [ "${DAIMOS_TSFS_GATE_MEDIA_V1527:-0}" = 1 ] ||
                    [ "${DAIMOS_TSFS_GATE_WRITE_V1528:-0}" = 1 ] ||
                    [ "${DAIMOS_TSFS_GATE_PARTIAL_V1529:-0}" = 1 ]; } &&
                    [ "$file" = "$cty_out" ] &&
                    [ "$pattern" != 'sim> ' ] &&
                    grep -F "${DAIMOS_TSFS_GATE_PREFIX_V1526:-DTFSMEDIA V1527} FAIL_" "$file" >/dev/null 2>&1; then
                        return 1
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

if [ "${DAIMOS_TSFS_GATE_INIT_V1525:-0}" = 1 ]; then
        # The original KINIT has already mounted its physical TSFS root
        # and installed the DTFS MRES. It now starts our one-shot gate as
        # real PID 1 instead of the usual /SYSTEM/INIT/LOGIN/DSH chain.
        # Validate actual kernel control flow on CTY, not a manufactured
        # exit status from a separate stub simulator.
        gate_prefix=${DAIMOS_TSFS_GATE_PREFIX_V1526:-"DTFSGATE V1525"}
        gate_stages=${DAIMOS_TSFS_GATE_STAGES_V1526:-"START MOUNTED FSINFO BUSY_REFUSED FD_REFUSED PASS"}
        if [ "${DAIMOS_TSFS_GATE_MEDIA_V1527:-0}" = 1 ] ||
            [ "${DAIMOS_TSFS_GATE_WRITE_V1528:-0}" = 1 ] ||
            [ "${DAIMOS_TSFS_GATE_PARTIAL_V1529:-0}" = 1 ]; then
                simh_media_exchange_v1527()
                {
                        console_start=`log_size "$cty_out"`
                        printf '\005' >&3
                        wait_new "$cty_out" 'sim> ' "$console_start" 150 ||
                            fail_logs 'v1527: SIMH break did not reach prompt'
                        for command do
                                console_start=`log_size "$cty_out"`
                                printf '%s\n' "$command" >&3
                                wait_new "$cty_out" 'sim> ' "$console_start" 150 ||
                                    fail_logs 'v1527: SIMH media command did not return'
                                if tail -c "+$((console_start + 1))" "$cty_out" |
                                    grep -Ei '^\?|Error [0-9]|not attached' >/dev/null; then
                                        fail_logs 'v1527: simulator media operation refused'
                                fi
                                if [ "${DAIMOS_TSFS_GATE_PARTIAL_V1529:-0}" = 1 ] &&
                                    [ "$command" = 'detach DTC3' ]; then
                                        if [ ! -e "$work/media/prewrite-v1529.tap" ]; then
                                                cp "$dtc3_media_v1530" \
                                                    "$work/media/prewrite-v1529.tap"
                                                python3 "$self/daimos-dtfs-partial-media-verify-v1529.py" \
                                                    seed "$work/media/prewrite-v1529.tap" \
                                                    "$work/media/prewrite-v1529.tap" ||
                                                    fail_logs 'v1529: invalid physical seed'
                                        else
                                                python3 "$self/daimos-dtfs-partial-media-verify-v1529.py" \
                                                    partial "$work/media/prewrite-v1529.tap" \
                                                    "$dtc3_media_v1530" ||
                                                    fail_logs 'v1529: no proven partial physical write'
                                        fi
                                fi
                        done
                        printf 'cont\n' >&3
                        # Input is addressed to the real running PID1's
                        # blocked CTY READCHAR, never to SIMH monitor mode.
                        printf 'A\r' >&3
                }
                if [ "${DAIMOS_TSFS_GATE_PARTIAL_V1529:-0}" = 1 ]; then
                        wait_new "$cty_out" "$gate_prefix READY_ARM" 0 ||
                            fail_logs 'v1529: no pre-partial-write checkpoint'
                        simh_media_exchange_v1527 \
                            'detach DTC3' \
                            "attach -q DTC3 $dtc3_media_v1530" \
                            'set DTC3 PARTIALWRITE=0145:1'
                        wait_new "$cty_out" 'V1529 PARTIALWRITE block 0145 after 1 changed word' 0 ||
                            fail_logs 'v1529: controller never interrupted after a changed word'
                        wait_new "$cty_out" "$gate_prefix WRITE_FAILED" 0 ||
                            fail_logs 'v1529: partial write was not refused'
                        wait_new "$cty_out" "$gate_prefix READY_VERIFY" 0 ||
                            fail_logs 'v1529: no post-partial-write checkpoint'
                        simh_media_exchange_v1527 \
                            'detach DTC3' \
                            "attach -q DTC3 $dtc3_media_v1530"
                else
                wait_new "$cty_out" "$gate_prefix READY_DETACH" 0 ||
                    fail_logs 'v1527: no pre-detach guest checkpoint'
                simh_media_exchange_v1527 'detach DTC3'
                if [ "${DAIMOS_TSFS_GATE_WRITE_V1528:-0}" = 1 ]; then
                        wait_new "$cty_out" "$gate_prefix WRITE_FAILED" 0 ||
                            fail_logs 'v1528: physical write not refused'
                        wait_new "$cty_out" "$gate_prefix READY_RESTORE" 0 ||
                            fail_logs 'v1528: no return checkpoint'
                        simh_media_exchange_v1527 \
                            "attach -q DTC3 $dtc3_media_v1530"
                else
                wait_new "$cty_out" "$gate_prefix OFFLINE_REFUSED" 0 ||
                    fail_logs 'v1527: missing physical read-failure refusal'
                wait_new "$cty_out" "$gate_prefix READY_SWAP" 0 ||
                    fail_logs 'v1527: no replacement checkpoint'
                simh_media_exchange_v1527 \
                    "attach -q DTC3 $work/media/replacement-v1527.tap"
                wait_new "$cty_out" "$gate_prefix REPLACEMENT_REFUSED" 0 ||
                    fail_logs 'v1527: different 72-bit identity was not refused'
                wait_new "$cty_out" "$gate_prefix READY_RESTORE" 0 ||
                    fail_logs 'v1527: no same-media return checkpoint'
                simh_media_exchange_v1527 \
                    "detach DTC3" \
                    "attach -q DTC3 $dtc3_media_v1530"
                fi
                fi
        fi
        for stage in $gate_stages; do
                wait_new "$cty_out" "$gate_prefix $stage" 0 ||
                    fail_logs "actual booted PID1 gate missing $stage"
        done
        if grep -F "$gate_prefix FAIL" "$cty_out" >/dev/null; then
                fail_logs 'real PID1 physical gate reported an error'
        fi
        printf '%s\n' "$tag: PASS (actual booted KCORE PID1 DTFS mount, FSINFO, cwd and retire)"
        exit 0
fi

wait_new "$dcs_out" 'Connected to the PDP6 simulator DCS device' 0 || \
        fail_logs 'DCS0 transport did not connect'
start=`log_size "$dcs_out"`
send_slow ''
wait_new "$dcs_out" 'LOGIN: ' "$start" || fail_logs 'DCS0 LOGIN did not reprompt'
start=`log_size "$dcs_out"`
send_slow ROOT
wait_new "$dcs_out" 'DSH V1' "$start" || fail_logs 'ROOT login did not enter DSH'

if [ "${DAIMOS_TSFS_GATE_RUN_V1525:-0}" = 1 ]; then
        start=`log_size "$dcs_out"`
        send_slow 'DTFSGATE'
        wait_new "$dcs_out" 'DTFSGATE V1525 PASS' "$start" ||
            fail_logs 'installed DTFS physical mount/FSINFO/cwd/unmount gate failed'
        wait_new "$dcs_out" '# ' "$start" ||
            fail_logs 'physical gate did not return to DSH'
        if tail -c "+$((start + 1))" "$dcs_out" |
            grep -F 'DTFSGATE V1525 FAIL' >/dev/null; then
                fail_logs 'physical gate explicitly reported failure'
        fi
        printf '%s\n' "$tag: PASS (booted native KCORE DTFS physical mount and cwd lifetime)"
        exit 0
fi

if [ "${DAIMOS_TSFS_MOUNT_PREFORMATTED_V1525:-0}" != 1 ]; then
        start=`log_size "$dcs_out"`
        # With a DTC-selected root, DTFS MRES is installed. Exercise the
        # real target native filesystem formatter unless testing mounting
        # from an independently produced complete physical DTFS image.
        send_slow 'MKFS.DTFS -O NATIVE /DEV/DTC3'
        wait_new "$dcs_out" '# ' "$start" || \
            fail_logs 'secondary DTFS format did not return'
        if tail -c "+$((start + 1))" "$dcs_out" | \
            grep -F 'MKFS.DTFS:' >/dev/null; then
                fail_logs 'secondary MKFS returned a command error'
        fi
        start=`log_size "$dcs_out"`
        send_slow 'FSCK.DTFS -O NATIVE /DEV/DTC3'
        wait_new "$dcs_out" 'FSCK.DTFS NATIVE OK' "$start" || \
            fail_logs 'secondary native DTFS failed validation'
        wait_new "$dcs_out" '# ' "$start" || \
            fail_logs 'secondary DTFS check did not return'
        if tail -c "+$((start + 1))" "$dcs_out" | \
            grep -F 'FSCK.DTFS:' >/dev/null; then
                fail_logs 'secondary FSCK returned a command error'
        fi
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
