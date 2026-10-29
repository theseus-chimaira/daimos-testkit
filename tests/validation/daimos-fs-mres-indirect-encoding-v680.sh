#!/bin/sh
# Standalone assembly/link regression: indexed indirect calls via patched JRST.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mres-indirect-v680.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/probe.s" <<'EOF'
        .text
        .globl  v680_start
v680_start:
        movei   7,0
        pushj   17,@v680_service(7)
        popj    17,
v680_service:
        jrst    v680_target
v680_target:
        movei   1,1
        popj    17,
EOF
das -C -F -O "$work/probe.dobj" "$work/probe.s"
dlink -b 020 -o "$work/probe.dxr" -M "$work/probe.map" "$work/probe.dobj"
pdp10-dec-none-objdump -d "$work/probe.dobj" > "$work/objdump.txt"
grep -Eq 'PUSHJ[[:space:]]+17,@' "$work/objdump.txt"
grep -Eq 'JRST[[:space:]]+0,' "$work/objdump.txt"
grep -Eq '^v680_start[[:space:]]+000020$' "$work/probe.map"
python3 - "$work/objdump.txt" <<'PY'
import re,sys
text=open(sys.argv[1]).read()
matches=re.findall(r'^[0-7]{6}:\s+([0-7]{6}),,([0-7]{6})\s+PUSHJ\s+17,@',text,re.M)
assert len(matches)==1, matches
# Opcode 260 and index AC7 plus indirect bit are encoded in the LH.
assert int(matches[0][0],8)==0o260767, matches
print('v680 indirect PUSHJ opcode and index encoding: PASS')
PY
printf '%s\n' 'v680: assembler, encoded indirect bit, linker symbol: PASS'
