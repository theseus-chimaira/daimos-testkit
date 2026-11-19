#!/bin/sh
# Exact v1665 -> v1666 source-linked MRES/KCORE image RAM deltas.
# All four roots must be complete independently built image directories.
set -eu
: "${V1666_KCC_OLD:?full KCC v1665 build dir}"
: "${V1666_KCC_NEW:?full KCC v1666 build dir}"
: "${V1666_GCC_OLD:?GCC lowmem v1665 build dir}"
: "${V1666_GCC_NEW:?GCC lowmem v1666 build dir}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export PDP10_PREFIX
python3 - "$V1666_KCC_OLD" "$V1666_KCC_NEW" \
    "$V1666_GCC_OLD" "$V1666_GCC_NEW" \
    "$PDP10_PREFIX/bin/pdp10-objdump" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

old_kcc, new_kcc, old_gcc, new_gcc = map(Path, sys.argv[1:5])
objdump = sys.argv[5]


def symbol(directory, map_file, name):
    source = (directory / map_file).read_text(encoding='ascii')
    matched = re.findall(r'^' + re.escape(name) +
                         r'\s+([0-7]+)\s*$', source, re.M)
    if len(matched) != 1:
        raise SystemExit('v1666: missing/duplicate symbol ' + name +
                         ' in ' + str(directory / map_file))
    return int(matched[0], 8)


def resident(directory, filename):
    output = subprocess.check_output([objdump, '-h',
        str(directory / filename)], text=True)
    matched = re.findall(r'^mres:.*\bresident=(\d+)\b', output, re.M)
    if len(matched) != 1:
        raise SystemExit('v1666: missing resident section ' + filename)
    return int(matched[0])


def check_family(name, old, new, kcc):
    before = symbol(old, 'kcore.map', '__kcore_low_end')
    after = symbol(new, 'kcore.map', '__kcore_low_end')
    saved = before - after
    old_disk = resident(old, 'swapv481-mres.dobj')
    new_disk = resident(new, 'swapv481-mres.dobj')
    old_pure = resident(old, 'purev1612-mres.dobj')
    new_pure = resident(new, 'purev1612-mres.dobj')
    disk_delta = new_disk - old_disk
    pure_delta = new_pure - old_pure
    want = (114, 42, 90) if kcc else (111, 42, 90)
    if (saved, disk_delta, pure_delta) != want:
        raise SystemExit('FAIL v1666: unexpected ' + name +
            ' fixed/MRES RAM delta: ' +
            str((saved, disk_delta, pure_delta)) +
            ', expected ' + str(want))
    if symbol(new, 'kcore.map', 'proc_swap_term_v1666') <= 0:
        raise SystemExit('FAIL v1666: fixed terminal stub missing')
    fixed = (new / 'kcore.map').read_text(encoding='ascii')
    packed = (new / 'pure-mres-v1612.map').read_text(encoding='ascii')
    disk = (new / 'swap-mres-v481.map').read_text(encoding='ascii')
    if re.search(r'^pdp6_pure_detach_v1609\s+', fixed, re.M) or \
        not re.search(r'^pdp6_pure_detach_v1609\s+', packed, re.M) or \
        not re.search(r'^proc_swap_mres_terminal_v1666\s+', disk, re.M):
        raise SystemExit('FAIL v1666: backend owner in wrong memory image')
    print('v1666 ' + name + ': KCORE -' + str(saved) +
          ', DISK MRES +' + str(disk_delta) + ', PURE MRES +' +
          str(pure_delta) + ', net DISK -' + str(saved - disk_delta) +
          ', net PURE -' + str(saved - pure_delta) + ' words PASS')


check_family('KCC FULL', old_kcc, new_kcc, True)
check_family('GCC LOWMEM', old_gcc, new_gcc, False)
old_end = symbol(old_kcc, 'kinit.map', '__kinit_image_end')
new_end = symbol(new_kcc, 'kinit.map', '__kinit_image_end')
if new_end - old_end != 44:
    raise SystemExit('FAIL v1666: unexpected transient KINIT A/B delta')
print('v1666 KCC FULL transient KINIT +44 words PASS')
PY
