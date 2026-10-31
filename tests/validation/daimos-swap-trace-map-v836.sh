#!/bin/sh
# v836: retain reproducible full-system swap traces and both symbol maps.
# Does not treat MRES link-time addresses as permanently resident breakpoints.
set -eu
: "${TMPDIR:=$HOME/tmp}"
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${DAS_REPO:?}"
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
tag=daimos-swap-trace-v836
report="$TMPDIR/$tag.report"
export TMPDIR DAIMOS_MM_TRACE_KEEP=1 DAIMOS_SWAP_TRACE_V669=1
set +e
sh "$self/daimos-mm-swap-scheduler-v669.sh" > "$TMPDIR/$tag.log" 2>&1
rc=$?
set -e
boot=$(find "$TMPDIR" -maxdepth 9 -name swap-mres-v481.map \
    -path '*daimos-mm-swap-scheduler-v669-*' \
    -exec stat -c '%Y %n' {} \; | sort -nr | head -1 | cut -d' ' -f2-)
if [ -z "$boot" ]; then
    echo "$tag: no preserved SWAP MRES map; see $TMPDIR/$tag.log" >&2
    exit 1
fi
dir=${boot%/*}
simh="${dir%/build/system/boot/pdp6}/simh.out"
{
    echo "runner_exit=$rc"
    echo "boot=$dir"
    echo "simh_output=$simh"
    echo 'resident entry symbols:'
    for sym in proc_swap_service_one proc_swap_victim proc_sched_cursor; do
        awk -v sym="$sym" '$1==sym {print; found=1} END {if (!found) print sym " NOT FOUND"}' "$dir/kcore.map"
    done
    if [ -f "$simh" ]; then
        echo 'resident breakpoint hit counts:'
        for sym in proc_swap_service_one proc_swap_reclaim proc_swap_victim; do
            pc=$(awk -v sym="$sym" '$1==sym {print $2;exit}' "$dir/kcore.map")
            if [ -n "$pc" ]; then
                count=$(grep -c "Breakpoint, PC: $pc " "$simh" || true)
                echo "$sym $pc $count"
            fi
        done
    fi
    echo 'SWAP MRES link-map symbols (overlay addresses are NOT permanent):'
    for sym in proc_swap_mres_service_v481 proc_swap_service_pressure proc_swap_service_candidate_v834 proc_swap_exchange_pair_v826 proc_swap_exchange_execute_v832 proc_swap_exchange_run_v790; do
        awk -v sym="$sym" '$1==sym {print; found=1} END {if (!found) print sym " NOT FOUND"}' "$boot"
    done
} > "$report"
cat "$report"
echo "$tag: trace retained at $TMPDIR/$tag.log"
exit "$rc"
