#!/bin/sh
# v1517: real PDP-6 SIMH Type-551 selected/absent/reattached status.
# This demonstrates simulator behavior, NOT a hardware-safe removal verdict.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-dtc-select-status-v1517.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
simh=${SIMH_PDP6:-${PDP10_PREFIX:-$HOME/cross}/bin/pdp6}
test -x "$simh" || {
    echo 'v1517: missing PDP-6 SIMH binary' >&2
    exit 2
}

# The same legal SEARCH+SELECT command is used on physical DTC0 before
# attachment, while attached, and again after detachment. A final probe
# selects still-unattached physical DTC7 to prove that the raw status
# cannot identify membership in the selected TSFS root set.
# PDP-6 HALT is encoded explicitly: 254200,,001004 = HALT 001004.
cat > "$work/status-v1517.ini" <<EOF
set cpu 64k
set dtc enabled
deposit 1000 MOVEI 1,220200
deposit 1001 CONO 210,0(1)
deposit 1002 CONI 214,2
deposit 1003 MOVEM 2,2000
deposit 1004 254200001004
go 1000
examine 2000
attach dtc0 $work/dtc0-v1517.tap
go 1000
examine 2000
detach dtc0
go 1000
examine 2000
deposit 1000 MOVEI 1,220270
go 1000
examine 2000
exit
EOF

# Do not use instruction-count timeouts to judge tape motion; this is an
# immediate selected-transport status test that never transfers data.
timeout 25s "$simh" "$work/status-v1517.ini" > "$work/simh.log" 2>&1 || {
    echo 'v1517: simulator failed' >&2
    tail -55 "$work/simh.log" >&2
    exit 1
}
python3 - "$work/simh.log" <<'PY'
from pathlib import Path
import re
import sys

out = Path(sys.argv[1]).read_text()
status = [int(x, 8) for x in
          re.findall(r'(?m)^2000:\s*([0-7]{12})\s*$', out)]
halts = re.findall(r'HALT instruction, PC:\s*([0-7]{6})', out)
assert len(status) == 4, ('missing simulator statuses', status)
assert halts == ['001004'] * 4, ('wrong PDP-6 HALT sequence', halts)
assert status[0] == 0o4, ('DTC0 absent select', oct(status[0]))
assert status[1] & 0o4 == 0, ('DTC0 attached must not select-error',
                              oct(status[1]))
assert status[1] & 0o1000, ('DTC0 attached selection request',
                            oct(status[1]))
assert status[2] == 0o4, ('DTC0 detached select', oct(status[2]))
assert status[3] == 0o4, ('unrelated DTC7 absent select', oct(status[3]))
assert 'DTC0: 18b/36b format' in out, 'no genuine attached-media test'
print('PASS v1517: PDP-6 SIMH absent DTC0=%06o attached=%06o' %
      (status[0], status[1]))
print('PASS v1517: detached DTC0=%06o unrelated absent DTC7=%06o' %
      (status[2], status[3]))
print('PASS v1517: all four real PDP-6 HALT PCs verified')
PY
