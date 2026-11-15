#!/bin/sh
# Full 256K PDP-6, true two-member TSFS root, four separate secondary
# DTC media mounts, failed/replaced/returned DTC3 and healthy high IDs.
# Reuse ORIGINAL v1527 physical CTY/SIMH media exchange and KCORE.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
path_file=$(mktemp "$TMPDIR/daimos-fsinfo-v1595-evidence.XXXXXX")
trap 'rm -f "$path_file"' EXIT HUP INT TERM
export DAIMOS_TSFS_EVIDENCE_PATH_FILE_V1595="$path_file"
export DAIMOS_TSFS_KEEP_WORK=1
export DAIMOS_TSFS_GATE_TWO_MEMBER_ROOT_V1591=1
export DAIMOS_TSFS_GATE_FSINFO_HI_V1533=1
export DAIMOS_TSFS_GATE_MEDIA_V1527=1
export DAIMOS_TSFS_GATE_HI_MEDIA_V1595=1
export DAIMOS_TSFS_GATE_SOURCE_V1526=\
"$self/../target/daimos-dtfs-media-return-v1527.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSMEDIA V1527'
export DAIMOS_TSFS_GATE_STAGES_V1526=\
'START MOUNTED5_V1595 READY_DETACH OFFLINE_HIGH_STABLE_V1595 OFFLINE_REFUSED READY_SWAP REPLACEMENT_HIGH_STABLE_V1595 REPLACEMENT_REFUSED READY_RESTORE RETURN_ALL_STABLE_V1595 RETURN_VERIFIED RETIRED_ALL_V1595 PASS'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
work=$(cat "$path_file")
test -f "$work/cty.out"
python3 "$self/daimos-p1c-dtfs-highslot-verify-v1596.py" --self-test \
    "$work" 1595 "$work/v1595-physical-verification.txt" \
    > "$work/v1595-raw-oracle.log"
cat "$work/v1595-physical-verification.txt"
echo 'PASS v1595: physical high-slot FSINFO refusal, return and raw oracle'
