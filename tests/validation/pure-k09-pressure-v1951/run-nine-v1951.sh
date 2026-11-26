#!/bin/sh
# Same nine-owner native pipe/WAIT workload, adjusted to current KCC
# resident footprint. Do not touch the production kernel or child count.
set -eu
test "$#" = 2 || { echo "usage: $0 WORK {general|strict}" >&2; exit 2; }
work=$1
variant=$2
case "$variant" in general|strict) ;; *) exit 2;; esac
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mkdir "$work"
work=$(CDPATH= cd -- "$work" && pwd)
python3 - "$here/../pure-runtime-highwater-v1674/pipe-child-v1674.s" "$work/pipe-child-v1951.s" <<'PY'
from pathlib import Path
import sys
source,target=map(Path,sys.argv[1:])
s=source.read_text()
assert s.count('subi 01,6')==1
s=s.replace('subi 01,6','subi 01,3')
s=s.replace('PID2..PID6','PID2..PID3').replace('Five enlarged and four ordinary','Two enlarged and seven ordinary')
target.write_text(s)
PY
V1673_ONLY_VARIANT="$variant" V1673_KERNEL_COMPILER=kcc \
V1673_GROWN_CHILDREN=2 V1673_WORK_DIR="$work" KEEP_TEST=1 \
V1673_TIMEOUT="${V1673_TIMEOUT:-1150}" \
V1673_GUEST_C="$here/../pure-runtime-highwater-v1674/proc-pressure-v1674.c" \
V1673_CHILD_ASM="$work/pipe-child-v1951.s" \
sh "$here/../pure-runtime-reclaim-v1673/run-physical-v1673.sh"
