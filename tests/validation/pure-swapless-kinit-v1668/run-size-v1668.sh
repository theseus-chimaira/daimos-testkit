#!/bin/sh
# Compare two source-matched independently linked TSFS/PURE images:
# general tape boot (with disk-swap candidate) vs strict swapless.
set -eu
: "${V1668_GENERAL_BUILD:?general TSFS/PURE build directory required}"
: "${V1668_STRICT_BUILD:?strict TSFS/PURE build directory required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export PDP10_PREFIX
python3 - "$V1668_GENERAL_BUILD" "$V1668_STRICT_BUILD" \
    "$PDP10_PREFIX/bin/pdp10-objdump" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

general,strict=map(Path,sys.argv[1:3])
objdump=sys.argv[3]


def symbol(directory,filename,name,missing=False):
    source=(directory/filename).read_text(encoding='ascii')
    values=re.findall(r'^'+re.escape(name)+r'\s+([0-7]+)\s*$',
                      source,re.M)
    if missing:
        if values:
            raise SystemExit('FAIL v1668: forbidden symbol '+name)
        return 0
    if len(values)!=1:
        raise SystemExit('FAIL v1668: missing/duplicate symbol '+name+
                         ' in '+str(directory/filename))
    return int(values[0],8)


def resident(directory,filename):
    source=subprocess.check_output([objdump,'-h',str(directory/filename)],
                                   text=True)
    values=re.findall(r'^mres:.*\bresident=(\d+)\b',source,re.M)
    if len(values)!=1:
        raise SystemExit('FAIL v1668: no resident module '+filename)
    return int(values[0])


old_fixed=symbol(general,'kcore.map','__kcore_low_end')
new_fixed=symbol(strict,'kcore.map','__kcore_low_end')
if new_fixed!=old_fixed:
    raise SystemExit('FAIL v1668: fixed KCORE footprint changed')

old_pure=resident(general,'purev1612-mres.dobj')
new_pure=resident(strict,'purev1612-mres.dobj')
if old_pure!=new_pure:
    raise SystemExit('FAIL v1668: installed PURE MRES changed')

disk_words=resident(general,'swapv481-mres.dobj')
if disk_words<=0:
    raise SystemExit('FAIL v1668: invalid general disk MRES reference')
symbol(general,'kinit.map','proc_swap_mres_package_v481')
symbol(strict,'kinit.map','proc_swap_mres_package_v481',missing=True)
symbol(general,'kinit.map','proc_pure_mres_package_v1612')
symbol(strict,'kinit.map','proc_pure_mres_package_v1612')

old_end=symbol(general,'kinit.map','__kinit_image_end')
new_end=symbol(strict,'kinit.map','__kinit_image_end')
saving=old_end-new_end
if saving<=0 or saving<disk_words:
    raise SystemExit('FAIL v1668: linked image did not reclaim DISK MRES')

table=(strict/'module-table-runtime.s').read_text(encoding='ascii')
if '.set DAIMOS_SWAPLESS_ONLY_V1668,1' not in table or \
    '.word proc_swap_minit_v481,,0' not in table:
    raise SystemExit('FAIL v1668: strict MINIT table not assembled')

print('PASS v1668: KCORE unchanged (%06o octal)'%new_fixed)
print('PASS v1668: installed PURE MRES unchanged (%d words)'%new_pure)
print('PASS v1668: no linked DISK MRES (%d-word candidate)'%disk_words)
print('PASS v1668: KINIT end %06o -> %06o; %d transient words saved'%
      (old_end,new_end,saving))
PY
