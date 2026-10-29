#!/bin/sh
# Trace KINIT mount stages using symbols from the actually linked image.
# Exit zero only when the known pre-VFS failure is reproduced and classified.
set -eu
: "${PDP10_PREFIX:?}"
: "${DAIMOS_BOOT_V670:?set to an existing PDP-6 boot-image directory}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
boot=$DAIMOS_BOOT_V670
map=$boot/kinit.map
test -f "$map" && test -f "$boot/boot.ini"
work=$(mktemp -d "$TMPDIR/daimos-d6fs-stage-v670.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
"$self/../lib/daimos-simh-headless.sh" "$boot/boot.ini" \
    "$work/boot.ini" 32883 46883
python3 - "$map" "$work/boot.ini" <<'PY'
from pathlib import Path
import sys
sym={}
for line in Path(sys.argv[1]).read_text().splitlines():
    parts=line.split()
    if len(parts)>=2 and all(c in '01234567' for c in parts[1]):
        sym[parts[0]]=parts[1]
names=['blockset_boot_discover','blockset_boot_read',
       'd6fs_super_select','vfs_mount','vfs_stat','kinit_error18']
for name in names:
    if name not in sym:
        raise SystemExit('v670: missing linked symbol '+name)
p=Path(sys.argv[2])
s=p.read_text()
assert 'go 020\n' in s
for name in names:
    s=s.replace('go 020\n',
        'break '+sym[name]+';examine 1;go\ngo 020\n')
p.write_text(s)
PY
(cd "$boot" && TERM=dumb timeout -k 2s 40s \
    "$PDP10_PREFIX/bin/pdp6" "$work/boot.ini") >"$work/simh.log" 2>&1 || {
    tail -40 "$work/simh.log" >&2; exit 1;
}
python3 - "$map" "$work/simh.log" <<'PY'
from pathlib import Path
import re,sys
sym={p[0]:p[1] for line in Path(sys.argv[1]).read_text().splitlines()
     if len(p:=line.split())>=2}
s=Path(sys.argv[2]).read_text()
def hit(name):
    return bool(re.search(r'Breakpoint, PC:\s*0*'+sym[name]+r'\b',s))
if not(hit('blockset_boot_discover') and hit('blockset_boot_read')
       and hit('d6fs_super_select') and hit('kinit_error18')):
    raise SystemExit('v670: boot trace does not match known mount failure')
if hit('vfs_mount') or hit('vfs_stat'):
    raise SystemExit('v670: VFS reached; failure stage has changed')
print('v670: CONFIRMED KINIT mount failure before VFS (not a swap test PASS)')
PY
