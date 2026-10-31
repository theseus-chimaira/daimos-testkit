#!/bin/sh
# Build a clean pressure image, adding MRES entry breakpoints before boot.
# Instrument a private copy of the v669 runner; do not modify other tests.
set -eu
: "${TMPDIR:=$HOME/tmp}"
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${DAS_REPO:?}"
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-v839.XXXXXX")
runner="$work/daimos-mm-swap-scheduler-v669.sh"
trap ':' EXIT HUP INT TERM

# The v669 runner needs its adjacent CRT and SIMH helper files. Preserve
# the original directory for those references; change only trace setup.
python3 - "$self/daimos-mm-swap-scheduler-v669.sh" "$runner" "$self" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text()
source = source.replace('self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)',
                        'self="' + sys.argv[3] + '"', 1)
marker = "printf 'examine %s\\ngo 020\\nexit\\n' \"$capacity_addr\" >> \"$simh_ini\""
assert source.count(marker) == 1
injection = r'''# v839: runtime MRES base is checked using SWAP's installed trampoline.
# The base used for breakpoints comes from the previously measured v837
# image. If the image layout changes, fail rather than silently trusting
# unrelated breakpoint addresses.
service=$(awk '$1=="proc_swap_mres_service_v481" {print $2;exit}' "$boot/swap-mres-v481.map")
if [ "$service" != 002423 ]; then
    echo "v839: MRES layout changed; recalibrate runtime base: $service" >&2
    exit 1
fi
for sym in proc_swap_exchange_pair_v826 proc_swap_exchange_execute_v832 proc_swap_exchange_run_v790; do
    relative=$(awk -v name="$sym" '$1==name {print $2;exit}' "$boot/swap-mres-v481.map")
    [ -n "$relative" ] || exit 1
    pc=$(printf '%06o' "$((8#27632 + 8#$relative))")
    printf 'break %s;examine 1;examine 2;examine 17;go\n' "$pc" >> "$simh_ini"
    echo "v839: $sym at $pc" >&2
done
'''
# POSIX shell arithmetic cannot express base-eight values with 8#.
injection = injection.replace('8#27632 + 8#$relative', '027632 + 0$relative')
source = source.replace(marker, injection + '\n' + marker, 1)
pathlib.Path(sys.argv[2]).write_text(source)
PY
export DAIMOS_MM_TRACE_KEEP=1 DAIMOS_SWAP_TRACE_V669=1
set +e
sh "$runner" > "$work/runner.log" 2>&1
rc=$?
set -e
echo "v839 runner_exit=$rc work=$work"
tail -22 "$work/runner.log"
trace=$(find "$TMPDIR" -maxdepth 3 -name simh.out \
    -path '*daimos-mm-swap-scheduler-v669-*' -mmin -30 -print | \
    sort | tail -1)
if [ -n "$trace" ]; then
    echo "v839 trace=$trace"
    for pc in 020462 027632 030315 031171; do
        hits=$(grep -c "Breakpoint, PC: $pc " "$trace" || true)
        echo "v839 breakpoint $pc hits=$hits"
    done
    if grep -q 'Breakpoint, PC: 020462 (JRST 0,32255)' "$trace"; then
        echo 'v839 installed trampoline target 032255 confirmed'
    else
        echo 'v839 trampoline could not be confirmed' >&2
    fi
fi
exit "$rc"
