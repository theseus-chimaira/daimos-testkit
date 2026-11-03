#!/bin/sh
# The real PDP-6 provider lock must not trap fatal FILE cleanup in a wait.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-provider-fatal-contention-v1078.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1078 work: $work"; fi' EXIT HUP INT TERM
src=${PROVIDER_GATEWAY_SOURCE:-$DAIMOS_REPO/system/kernel/fs/fs_mres.s}
{
    printf '.text\n.globl fs_provider_reg_call\n'
    printf '.globl fs_memfs_service_jump\n.globl fs_dtfs_service_jump\n'
    printf '.globl fs_d6fs_service_jump\n.globl fs_tsfs_service_jump\n'
    sed -n '/^fs_provider_reg_call:/,/^; KCORE memory-pressure bridge/p' \
        "$src" | sed '$d'
} > "$work/gateway.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 20000 --timeout 15 \
    --workdir "$work/run" --name provider-fatal-contention-v1078 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-provider-fatal-contention-v1078.s" \
    "$work/gateway.s" > "$work/log" 2>&1 || {
        tail -60 "$work/log" >&2
        exit 1
    }
echo 'v1078: fatal foreign lease returns -5, ordinary wait and free dispatch PASS'
