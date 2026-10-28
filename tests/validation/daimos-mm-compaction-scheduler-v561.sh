#!/bin/sh
# Full-system relocation observation atop the accepted 256K swap-cycle test.
# No kernel instrumentation; observe the production VM move entry in SIMH.
set -eu
: "${PDP10_PREFIX:?}" "${DAIMOS_REPO:?}" "${DAS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
tag=daimos-mm-compaction-scheduler-v561
work=$(mktemp -d "$TMPDIR/$tag.XXXXXX")
trap 'if [ "${DAIMOS_MM_KEEP_WORK:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
mkdir -p "$work/user"
"$cc" -std=c99 -Os \
  -I"$DAIMOS_REPO/system/kernel/boot" \
  -I"$DAIMOS_REPO/system/kernel/core" \
  -I"$DAIMOS_REPO/system/kernel/drivers" \
  -I"$DAIMOS_REPO/system/kernel/fs" \
  -I"$DAIMOS_REPO/system/kernel/ipc" \
  -I"$DAIMOS_REPO/system/kernel/mm" \
  -I"$DAIMOS_REPO/system/kernel/modules" \
  -I"$DAIMOS_REPO/system/kernel/proc" \
  -I"$DAIMOS_REPO/system/kernel/storage" \
  -I"$DAIMOS_REPO/userland/libc" \
  -S "$self/daimos-mm-compaction-scheduler-v561.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
"$das" -C -F -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
  "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
  "$work/user/init.dobj" "$libgcc"
grep -Eq '^_start[[:space:]]+000020$' "$work/user/init.map"
PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
  BUILD="$work/boot" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
  BOOT_PROFILE=full BOOT_CORE_WORDS=01000000 SIMH_CPU_KWORDS=256 \
  COMPILER=gcc DAS_REPO="$DAS_REPO" \
  SYSTEM_INIT_DXR="$work/user/init.dxr" > "$work/build.log" 2>&1
boot="$work/boot"
dcs_port=$((30000 + ($$ % 10000)))
ge_port=$((45000 + ($$ % 10000)))
"$self/../lib/daimos-simh-headless.sh" "$boot/boot.ini" \
 "$boot/boot.headless.ini" "$dcs_port" "$ge_port"
compact_addr=$(awk '$1 == "mm_compact" { print $2; exit }' "$boot/kcore.map")
[ -n "$compact_addr" ] || exit 1
move_addr=$(awk '$1 == "vm_extent_move" { print $2; exit }' "$boot/kcore.map")
[ -n "$move_addr" ] || { echo "$tag: missing VM symbol" >&2; exit 1; }
sed '/^go 020$/,$d' "$boot/boot.headless.ini" > "$boot/boot.mm-observe-v544.ini"
cat >> "$boot/boot.mm-observe-v544.ini" <<EOF
break $compact_addr;examine $compact_addr;go
break $move_addr;examine $move_addr;go
go 020
exit
EOF
set +e
(cd "$boot" && TERM=dumb timeout -k 2s "${DAIMOS_MM_TIMEOUT:-240}s" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" boot.mm-observe-v544.ini) \
   > "$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "$tag: SIMH failed ($rc); transcript $work/simh.out" >&2
  tail -25 "$work/simh.out" >&2
  exit 1
fi
# SIMH breakpoint/examine output may interrupt the guest's character stream.
# Match across those debugger lines, but demand each guest phase and normal
# halt; the guest validates every surviving child's exit/data integrity.
python3 - "$work/simh.out" <<'PYMARK'
import re
import sys
trace = open(sys.argv[1], encoding='ascii', errors='replace').read()
if not re.search(r'<AB\[024000\+300000=.*?300000\]CQ.*?HALT instruction',
                 trace, re.S) or '!G' in trace or '!W' in trace:
    sys.exit('v561: FAIL: guest did not complete BRK/child-data assertions')
PYMARK
move_hits=$(grep -c "Breakpoint, PC: $move_addr " "$work/simh.out" || true)
compact_hits=$(grep -c "Breakpoint, PC: $compact_addr " "$work/simh.out" || true)
[ "$move_hits" -gt 0 ] || { echo "$tag: INCONCLUSIVE: compaction $compact_hits, relocations $move_hits"; exit 1; }
echo "$tag: PASS (compaction $compact_hits, relocations $move_hits, guest CQ)"
