#!/bin/sh
# Mutate original physical PDP-6 CTY/MM evidence, never kernel state.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
if [ "$#" -ne 3 ]; then
    echo "usage: $0 STRICT48_EVIDENCE STRICT_BUILD FIXTURE_MAP" >&2
    exit 2
fi
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
source_dir=$1
strict_build=$2
fixture_map=$3
work=$(mktemp -d "$TMPDIR/daimos-v1672-negative.XXXXXX")
keep=${KEEP_TEST:-0}
trap 'if [ "$keep" = 1 ]; then echo "v1672 negative evidence: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
test -s "$source_dir/strict-48-console.clean"
test -s "$source_dir/strict-48-report.json"
test -s "$strict_build/kcore.map"
test -s "$fixture_map"

python3 - "$source_dir" "$strict_build/kcore.map" "$work" <<'PY'
import json
import re
import sys
from pathlib import Path

source,coremap,work=map(Path,sys.argv[1:])
original=(source/'strict-48-console.clean').read_text(encoding='ascii')
symbols=coremap.read_text(encoding='ascii')
names=re.findall(r'^mm_arenas\s+([0-7]+)\s*$',symbols,re.M)
if len(names)!=1:
    raise SystemExit('v1672 MM arena mutation map symbol drift')
arena=int(names[0],8)
marker='V1672 HOLD A'
end='V1672 RELEASE A'
if original.count(marker)!=1 or original.count(end)!=1:
    raise SystemExit('v1672 original physical CTY markers ambiguous')
before,after=original.split(marker,1)
region,suffix=after.split(end,1)
pattern=r'^((?:sim> )?0*%o:\s+)[0-7]{12}\s*$'%arena
if len(re.findall(pattern,region,re.M))!=1:
    raise SystemExit('v1672 real physical arena mutation anchor missing')
altered=re.sub(pattern,r'\g<1>777777777777',region,count=1,flags=re.M)
(work/'unsafe-arena.log').write_text(before+marker+altered+end+suffix,
                                      encoding='ascii')
(work/'unsafe-no-release.log').write_text(
    original.replace('V1672 RELEASE B','V1672 INVALID B',1),
    encoding='ascii')
report=json.loads((source/'strict-48-report.json').read_text(encoding='ascii'))
report['pressure']['free_words']+=1
report['samples'][1]['free_words']+=1
(work/'unsafe-free.json').write_text(json.dumps(report),encoding='ascii')
report=json.loads((source/'strict-48-report.json').read_text(encoding='ascii'))
report['pressure']['process_aprs'][0]['owner']=report['pressure']['process_aprs'][1]['owner']
report['samples'][1]['process_aprs'][0]['owner']=report['samples'][1]['process_aprs'][1]['owner']
(work/'unsafe-owner.json').write_text(json.dumps(report),encoding='ascii')
PY

for variant in unsafe-arena unsafe-no-release; do
    if python3 "$here/measure-v1672.py" \
        "$fixture_map" "$strict_build/kcore.map" \
        "$work/$variant.log" 48 "$work/$variant.json" \
        > "$work/$variant-refusal.log" 2>&1; then
        echo "FAIL v1672: unsafe physical $variant escaped native oracle" >&2
        keep=1;exit 1
    fi
    grep -q '^FAIL v1672 physical RUN/WAIT memory:' \
        "$work/$variant-refusal.log" || {
        cat "$work/$variant-refusal.log" >&2;keep=1;exit 1;
    }
    echo "v1672: executed unsafe physical $variant rejected"
done

for variant in unsafe-free unsafe-owner; do
    rc=0
    if python3 - "$here/compare-v1672.py" \
        "$work/$variant.json" > "$work/$variant-refusal.log" 2>&1 <<'PY'
import importlib.util
import json
import sys
from pathlib import Path
path,source=sys.argv[1:]
spec=importlib.util.spec_from_file_location('v1672compare',path)
mod=importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
try:
    mod.load(source,48)
except ValueError as exc:
    print('v1672 expected physical summary refusal:',exc)
    raise SystemExit(22)
PY
    then
        echo "FAIL v1672: forged $variant physical summary passed" >&2
        keep=1;exit 1
    else
        rc=$?
    fi
    if [ "$rc" -ne 22 ] || \
        ! grep -q '^v1672 expected physical summary refusal:' \
            "$work/$variant-refusal.log"; then
        echo "FAIL v1672: unexpected error in $variant oracle" >&2
        cat "$work/$variant-refusal.log" >&2
        keep=1;exit 1
    fi
    echo "v1672: executed unsafe $variant summary rejected"
done
echo 'PASS v1672: physical MM corruption and CTY witness mutants'
