#!/bin/sh
# Execute the current slot-0 service leaf against a no-partner native guest.
# No production source is patched; the tests live only in daimos-testkit.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-no-partner-v1301.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1301 work: $work"; fi' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_swap_mres_service_v481\n'
    printf '.equ PROC_SCHED_SWAP_REQUEST,0400\n'
    printf '.equ PROC_SLOT_MASK,0377\n'
    printf '.equ PROC_STATE_RUN,2\n'
    printf '.equ PROC_TRANSITION_RH,0200000\n'
    printf '.equ PROC_SCHED_READY_ONCE,01000\n'
    printf '.equ SYS_EVENT_TERM,1\n'
    sed -n '/^proc_swap_mres_service_v481:$/,/^proc_swap_mres_reclaim_v481:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
} > "$work/service.s"
grep -q '^proc_swap_service_no_pair_v834:$' "$work/service.s"
grep -q '^proc_swap_service_failed:$' "$work/service.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 150000 --timeout 20 \
    --workdir "$work/run" --name swap-no-partner-v1301 \
    --expect __test_exit=0 --expect __stage=4 \
    --expect __in_calls=3 --expect __pair_calls=3 \
    --expect __event_calls=1 --expect __exchange_calls=0 \
    --expect __post_cursor=2 --expect __post_state=200000000000 \
    --expect __post_backing=012345 --expect __service_rc=0 \
    "$self/daimos-test-crt0-v1.s" "$work/service.s" \
    "$self/daimos-swap-no-partner-v1301.s" > "$work/log" 2>&1 || {
        tail -65 "$work/log" >&2
        exit 1
    }
echo 'v1301: real PDP-6 no-partner cooldown, owned backing, fatal versus pressure and successful restore PASS'
