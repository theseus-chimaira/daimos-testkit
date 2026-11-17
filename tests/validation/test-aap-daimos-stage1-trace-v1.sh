#!/bin/sh
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR/aap-daimos-stage1-trace-v1"
w="$TMPDIR/aap-daimos-stage1-trace-v1"
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
cat > "$w/init.ini" <<INI
mkdev apr apr166
mkdev ptr ptr760 1
mkdev fmem fmem162 0
mkdev mem0 moby mem_0
connectio ptr apr
connectmem fmem 0 apr -1
connectmem mem0 0 apr 0
mount ptr $root/DAIMOS/build/system/boot/pdp6/stage1-dsk.pt
INI
cat > "$w/bootstrap.txt" <<'BOOT'
power on
deposit 20 710600000060
deposit 21 710740000010
deposit 22 254000000021
deposit 23 710440000026
deposit 24 710740000010
deposit 25 254000000024
deposit 26 000000000000
deposit 27 254000000021
ptrmotor ptr on
start 20
BOOT
(cd "$root/pdp6/emu" && cc -O2 -o "$w/pdp6_n" main_net.c emu.c apr.c mem.c tty.c pt.c dc.c dt.c pclk.c netmem.c netcons.c cmd.c util.c threading.c rtc.c ../tools/pdp6common.c -lpthread -lm)
(
 cd "$w"
 rm -f console.fifo; mkfifo console.fifo
 (cat bootstrap.txt; sleep 4) > console.fifo &
 PDP6_AAP_TIMING_TRACE_V1=1 PDP6_AAP_CLASS_TRACE_V1=1 timeout 3 ./pdp6_n < console.fifo > guest.log 2> guest.err || test "$?" -eq 124
 wait || :
)
python3 - "$w/guest.err" <<'PY'
import sys,re,collections
s=open(sys.argv[1]).read();c=collections.Counter(int(x,8) for x in re.findall(r'AAP_TIMING_V1 IT0 tick=\d+ pc=([0-7]{6})',s));print('AAP stage1 bounded trace: samples',sum(c.values()),'distinct',len(c),'top',[(oct(p),n) for p,n in c.most_common(14)],'minmax',tuple(map(oct,(min(c),max(c)))) if c else None,'exceptions',len(re.findall('AAP_CLASS_EVENT',s)))
assert c and any(pc >= 0o400 for pc in c), 'stage-one handoff never observed'
assert all(pc < 0o1000 for pc in c), 'new instruction region observed; independently verify before interpreting'
assert all(c.get(pc,0) > 0 for pc in (0o460,0o461,0o463,0o464,0o465)), 'expected unsupported disk-controller poll loop changed'
print('STAGE-ONE ADVANCED; KCORE/MRES BOOT UNVERIFIED (DSK270 is not supported by this AAP emulator)')
PY
