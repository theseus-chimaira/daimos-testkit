#!/bin/sh
# Replay unchanged native user fixtures on the actual 64K KA10 kernel.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
test "$#" = 4
machine=$1
mode=$2
w=$3
port=$4
case "$machine" in ka10) simulator=pdp10-ka;; pdp6) simulator=pdp6;; *) exit 2;; esac
case "$mode" in
 lifecycle) fixture=daimos-process-lifecycle-v1; users=1;;
 events) fixture=daimos-process-events-v1; users=1;;
 scheduler) fixture=daimos-scheduler-multiproc-v1; users=5;;
 protection) fixture=daimos-apr-user-protection-v1; users=1;;
 *) exit 2;;
esac
mkdir "$w"
w=$(cd "$w" && pwd)
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
set --
for d in boot core drivers fs mm modules proc storage; do
    set -- "$@" "-I$DAIMOS_REPO/system/kernel/$d"
done
"$cc" -std=c99 -Os "$@" -I"$DAIMOS_REPO/userland/libc" -S "$here/../$fixture.c" -o "$w/init.s"
"$das" -C -F -O "$w/init.dobj" "$w/init.s"
"$das" -C -F -O "$w/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$w/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$dlink" -b 020 -o "$w/init.dxr" -M "$w/init.map" \
    "$w/crt0.dobj" "$w/syscall.dobj" "$w/init.dobj" "$("$cc" -print-libgcc-file-name)"
export PATH="$PDP10_PREFIX/bin:$PATH"
make -C "$DAIMOS_REPO/system/boot/pdp6" -j2 image DAIMOS_MACHINE="$machine" \
    ROOT=disk BOOT=dsk BOOT_PROFILE=lowmem COMPILER=kcc BOOT_CORE_WORDS=0200000 \
    SIMH_CPU_KWORDS=64 PROC_BOOT_USERS="$users" SYSTEM_INIT_DXR="$w/init.dxr" \
    BUILD="$w/build" >"$w/build.log" 2>&1
sh "$here/../../lib/daimos-simh-headless.sh" "$w/build/boot.ini"     "$w/headless.ini" "$port" "$((port+1000))"
python3 - "$w" "$mode" "$port" <<'PY'
from pathlib import Path
import sys
w=Path(sys.argv[1])
mode,port=sys.argv[2:]
lines=[]
for line in (w/"headless.ini").read_text().splitlines():
    if line.startswith("attach -q dcs0 "):
        line="attach -q dcs0 "+port
    if line.startswith("attach -q ge0 "):
        line="attach -q ge0 "+str(int(port)+1000)
    if mode=="scheduler" and line in ("boot ptr","go 020"):
        lines.append("set throttle 8M")
    lines.append(line)
(w/"run.ini").write_text("\n".join(lines)+"\n")
PY
TERM=dumb timeout -k 3s 180s stdbuf -o0 -e0 "$PDP10_PREFIX/bin/$simulator" "$w/run.ini" >"$w/console.log" 2>&1
python3 "$here/verify-v1974.py" "$machine" "$mode" "$w/console.log"
