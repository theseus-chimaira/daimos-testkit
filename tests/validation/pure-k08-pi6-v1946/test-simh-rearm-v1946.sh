#!/bin/sh
# Characterize actual SIMH breakpoint rearm; independent tiny simulator.
set -eu
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
w=$(mktemp -d "$TMPDIR/k08-simh-break-rearm-v1946.XXXXXX")
trap 'echo "v1946 monitor probe evidence: $w"' EXIT
cat > "$w/probe.ini" <<'EOF'
set cpu 48k
deposit 1000 201040000001
deposit 1001 350040000001
deposit 1002 254000001001
break 1001
go 1000
echo FIRST
examine 1
nobreak all
break 1001
cont
echo REARMED
examine 1
cont
echo NEXT
examine 1
exit
EOF
TERM=dumb timeout 10s "$PDP10_PREFIX/bin/pdp6" "$w/probe.ini" >"$w/probe.log" 2>&1
python3 - "$w/probe.log" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text()
assert len(re.findall(r'Breakpoint, PC: 001001\b',s))==3
for tag,value in [('FIRST',1),('REARMED',1),('NEXT',2)]:
    assert re.search(r'(?m)^%s\n1:\s*%012o$'%(tag,value),s)
print('PASS v1946: rearm repeats same PC/AC without executing; normal CONT advances')
PY
