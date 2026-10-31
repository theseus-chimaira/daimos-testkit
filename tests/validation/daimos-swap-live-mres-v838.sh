#!/bin/sh
# Resolve the runtime SWAP MRES base from the installed KCORE trampoline.
# Requires a retained native v837 boot and the corresponding SIMH trace.
set -eu
: "${TMPDIR:=$HOME/tmp}"
: "${PDP10_PREFIX:?}"
: "${DAIMOS_SWAP_BOOT_V838:?set to preserved build/system/boot/pdp6}"
boot=$DAIMOS_SWAP_BOOT_V838
map=$boot/swap-mres-v481.map
kmap=$boot/kcore.map
trace=${boot%/build/system/boot/pdp6}/simh.out
test -f "$map" && test -f "$kmap" && test -f "$trace"
service=$(awk '$1=="proc_swap_mres_service_v481" {print $2;exit}' "$map")
trampoline=$(awk '$1=="proc_swap_service_one" {print $2;exit}' "$kmap")
# Examine the first actual service-entry breakpoint, not an assumed base.
target=$(awk -v pc="$trampoline" '
    $0 ~ "Breakpoint, PC: " pc " " {
        if (match($0, /JRST 0,[0-7]+/)) {
            word=substr($0,RSTART,RLENGTH); sub(/^JRST 0,/,"",word);
            print word; exit
        }
    }' "$trace")
test -n "$service" && test -n "$target"
base=$((0$target - 0$service))
test "$base" -gt 0
out="$TMPDIR/daimos-swap-live-mres-v838.ini"
sed '/^go 020$/,$d' "$boot/boot.headless.ini" > "$out"
printf 'examine %s\n' "$trampoline" >> "$out"
for sym in proc_swap_exchange_pair_v826 proc_swap_exchange_execute_v832 proc_swap_exchange_run_v790; do
    relative=$(awk -v name="$sym" '$1==name {print $2;exit}' "$map")
    if [ -z "$relative" ]; then
        echo "v838: missing $sym" >&2
        exit 1
    fi
    pc=$(printf '%06o' "$((base + 0$relative))")
    printf 'break %s;examine 1;examine 2;examine 17;go\n' "$pc" >> "$out"
    printf '%s relative=%s runtime=%s\n' "$sym" "$relative" "$pc"
done
printf 'go 020\nexit\n' >> "$out"
printf 'v838 runtime_base=%06o trampoline_target=%s ini=%s\n' "$base" "$target" "$out"
if [ "${DAIMOS_SWAP_DRY_RUN_V838:-0}" = 1 ]; then
    exit 0
fi
cd "$boot"
log="$TMPDIR/daimos-swap-live-mres-v838.log"
set +e
TERM=dumb timeout -k 2s 90s "$PDP10_PREFIX/bin/pdp6" "$out" > "$log" 2>&1
rc=$?
set -e
if grep -q '?RT' "$log"; then
    echo 'v838: root/INIT boot failure (?RT), exchange path not exercised' >&2
    exit 1
fi
if [ "$rc" -ne 0 ]; then
    echo "v838: simulator exit $rc" >&2
    exit 1
fi
if ! grep -q '<w' "$log"; then
    echo 'v838: no writer workload marker; trace is inconclusive' >&2
    exit 1
fi
