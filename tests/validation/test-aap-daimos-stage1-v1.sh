#!/bin/sh
# Observe a real DAIMOS stage-one tape bootstrap on the PDP-6 AAP emulator.
# RUNNING is not a boot success; this is only an input/mount smoke test.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
: "${TMPDIR:=$HOME/tmp}"
: "${DAIMOS_STAGE1_PT:?Provide the exact DAIMOS stage-one tape image}"
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/aap-daimos-stage1-v1.XXXXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/init.ini" <<INI
mkdev apr apr166
mkdev ptr ptr760
mkdev fmem fmem162 0
mkdev mem0 moby mem_0
connectio ptr apr
connectmem fmem 0 apr -1
connectmem mem0 0 apr 0
mount ptr $DAIMOS_STAGE1_PT
INI
cat > "$work/bootstrap.txt" <<'BOOT'
power on
deposit 20 710600000060
deposit 21 710740000010
deposit 22 254000000021
deposit 23 710440000026
deposit 24 710740000010
deposit 25 254000000024
deposit 26 000000000000
deposit 27 254000000021
start 20
cpustatus
examine 20
quit
BOOT
(
 cd "$root/../pdp6/emu"
 ${CC:-cc} -O2 -o "$work/pdp6_n" main_net.c emu.c apr.c mem.c tty.c pt.c dc.c dt.c pclk.c netmem.c netcons.c cmd.c util.c threading.c rtc.c ../tools/pdp6common.c -lpthread -lm
)
(cd "$work" && timeout 10 "$work/pdp6_n" < bootstrap.txt > guest.log 2> guest.err)
grep -q '000020: 710600000060' "$work/guest.log"
grep -q 'APR_STATUS_V1 RUNNING' "$work/guest.log"
# This intentionally does NOT assert kernel entry, MRES loads or boot success.
printf 'AAP DAIMOS stage-one tape mount/launch: PASS (boot unverified)\n'
