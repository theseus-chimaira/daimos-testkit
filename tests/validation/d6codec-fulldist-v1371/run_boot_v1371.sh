#!/bin/sh
# Native PDP-6 full-distribution runtime exercise, after v1370 and
# build_full_root_v1371.py.  Never boot from shared pristine media.
set -eu
: "${TMPDIR:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-fulldist-v1371"
v1370="$TMPDIR/d6codec-fullboot-v1370"
base="$work/disk-pristine-v1371"
disk="$work/disk-runtime-v1371"
out="$work/boot-runtime-v1371.out"
ini="$work/boot-runtime-v1371.simh"
mkdir -p "$disk"
for i in 0 1 2 3; do
    cp "$base/dsk$i.dsk" "$disk/dsk$i.dsk"
done

python3 - "$v1370/boot-grouped-v1370.simh" "$ini" "$v1370" "$disk" <<'PY'
from pathlib import Path
import sys
source, target, old, new = sys.argv[1:]
contents = Path(source).read_text()
marker = old + "/disk-grouped-v1370/"
if contents.count(marker) != 4:
    raise SystemExit("v1371: unexpected v1370 grouped SIMH disk configuration")
contents = contents.replace(marker, new + "/")
if contents.count("go 020") != 1 or contents.count("grouped-kinit-v1370.dta") != 1:
    raise SystemExit("v1371: grouped KINIT bootstrap missing")
Path(target).write_text(contents)
PY

fifo="$work/simh-input-v1371.fifo"
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
    TERM=dumb exec "$v1370/pty-run-v1370" -r "$PDP10_PREFIX/bin/pdp6" \
        "$ini" <"$fifo" >"$out" 2>&1
) &
child=$!

log_bytes()
{
    if [ -f "$out" ]; then wc -c < "$out" | tr -d ' '; else echo 0; fi
}
wait_new()
{
    wanted="$1"
    offset="$2"
    max=${3:-1100}
    n=0
    while [ "$n" -lt "$max" ]; do
        if tail -c "+$((offset + 1))" "$out" 2>/dev/null |
            grep -F "$wanted" >/dev/null 2>&1; then
            return 0
        fi
        if ! kill -0 "$child" 2>/dev/null; then
            echo "v1371: simulator terminated before $wanted" >&2
            tail -55 "$out" >&2
            return 1
        fi
        sleep .1
        n=$((n + 1))
    done
    echo "v1371: timeout before $wanted" >&2
    tail -55 "$out" >&2
    return 1
}

wait_new 'LOGIN: ' 0
echo 'V1371_FULL_LOGIN_PASS'
start=$(log_bytes)
sleep .3
for ch in R O O T; do
    printf '%s' "$ch" >&3
    sleep .05
done
printf '\r' >&3
wait_new '# ' "$start"
echo 'V1371_FULL_DSH_PASS'

for command in \
    'ECHO V1371FULL' \
    'LS /SYSTEM/EXEC' \
    'CAT /CONFIG/FSTAB' \
    'GREP MEMFS /CONFIG/FSTAB' \
    'WC /CONFIG/FSTAB' \
    'STAT /SYSTEM/EXEC/DSH' \
    'LS /OPTION/BASE/EXEC'; do
    start=$(log_bytes)
    printf '%s\r' "$command" >&3
    wait_new '# ' "$start"
    echo "V1371_FULL_COMMAND_RETURNED $command"
done

python3 - "$out" <<'PY'
from pathlib import Path
import re
import sys
raw = Path(sys.argv[1]).read_bytes().replace(b"\r\n", b"\n")

def check(label, expression):
    if not re.search(expression, raw, re.I):
        raise SystemExit("v1371: command output missing: " + label)
    print("V1371_FULL_COMMAND_PASS " + label)

# Require actual output, not merely the interactive line echo.
check("ECHO", rb"\nV1371FULL\n# ")
for name in (b"LOGIN", b"DSH", b"GREP", b"WC", b"MAKE"):
    check("LS_SYSTEM_EXEC_" + name.decode("ascii"),
          rb"\nF " + name + rb"\n")
check("CAT_FSTAB", rb"\n# DAIMOS FSTAB V1\n")
check("GREP_MEMFS", rb"\nMEMFS:/TEMP:4096\n")
check("WC_FSTAB", rb"\n3 7 55\n")
check("STAT_DSH", rb"\n/SYSTEM/EXEC/DSH TYPE 2 WORDS [1-9][0-9]* MODE 0555 ")
for name in (b"DAS", b"DARC", b"DLINK", b"OBJDUMP", b"KCC"):
    check("NATIVE_TOOL_" + name.decode("ascii"), rb"\nF " + name + rb"\n")
PY

start=$(log_bytes)
printf 'EXIT\r' >&3
wait_new 'LOGIN: ' "$start"
echo 'V1371_FULL_RESPAWN_PASS'
if grep -E 'INIT: RUN FAILED|\?RT|HALT instruction' "$out" >/dev/null; then
    echo 'v1371: kernel failure or INIT RUN failure' >&2
    tail -65 "$out" >&2
    exit 1
fi
echo 'PASS v1371: full standard D6FS root, grouped commands, native tools inventory and LOGIN respawn'
