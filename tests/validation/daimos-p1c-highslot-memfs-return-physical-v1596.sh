#!/bin/sh
# Real PDP-6: two separate high/low Type-551 media failures with live
# independently writable MEMFS and remaining DTFS mounts intact.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
path_file=$(mktemp "$TMPDIR/daimos-p1c-v1596-evidence.XXXXXX")
trap 'rm -f "$path_file"' EXIT HUP INT TERM
export DAIMOS_TSFS_EVIDENCE_PATH_FILE_V1595="$path_file"
export DAIMOS_TSFS_KEEP_WORK=1
export DAIMOS_TSFS_GATE_TWO_MEMBER_ROOT_V1591=1
export DAIMOS_TSFS_GATE_FSINFO_HI_V1533=1
export DAIMOS_TSFS_GATE_MEDIA_V1527=1
export DAIMOS_TSFS_GATE_HI_MEDIA_V1595=1
export DAIMOS_TSFS_GATE_MEMFS_HILOSS_V1596=1
export DAIMOS_TSFS_GATE_SOURCE_V1526=\
"$self/../target/daimos-dtfs-media-return-v1527.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSMEDIA V1527'
export DAIMOS_TSFS_GATE_STAGES_V1526=\
'START RAM_SEEDED_V1596 MOUNTED5_V1595 READY_DETACH OFFLINE_HIGH_STABLE_V1595 OFFLINE_REFUSED READY_SWAP REPLACEMENT_HIGH_STABLE_V1595 REPLACEMENT_REFUSED READY_RESTORE RETURN_ALL_STABLE_V1595 RETURN_VERIFIED READY_HI_DETACH_V1596 HIGH_OFFLINE_RAM_WRITE_V1596 READY_HI_RETURN_V1596 HIGH_RETURNED_V1596 RETIRED_ALL_V1595 PASS'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
work=$(cat "$path_file")
test -f "$work/cty.out"
python3 "$self/daimos-p1c-dtfs-highslot-verify-v1596.py" --self-test \
    "$work" 1596 "$work/v1596-physical-verification.txt" \
    > "$work/v1596-raw-oracle.log"
cat "$work/v1596-physical-verification.txt"
echo 'PASS v1596: physical DTC3/DTC6 loss and independent MEMFS progress'
