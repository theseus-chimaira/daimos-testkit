#!/bin/sh
# Production PDP-6 FS register gateway with nested live-owner requests.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-provider-inflight-v1088.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1088 work: $work"; fi' EXIT HUP INT TERM
{
    printf '.text\n.globl fs_provider_reg_call\n'
    printf '.globl fs_memfs_service_jump\n.globl fs_dtfs_service_jump\n'
    printf '.globl fs_d6fs_service_jump\n.globl fs_tsfs_service_jump\n'
    sed -n '/^fs_provider_reg_call:/,/^; KCORE memory-pressure bridge/p' \
        "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" | sed '$d'
} > "$work/gateway.s"
run_native() {
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 30000 --timeout 15 \
        --workdir "$work/run-$1" --name "provider-inflight-v1088-$1" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-provider-inflight-owner-v1088.s" \
        "$2" > "$work/log-$1" 2>&1
}
run_native positive "$work/gateway.s" || {
    tail -70 "$work/log-positive" >&2
    exit 1
}
# Deliberately make either fatal foreign or recursive contention sleep.
# Both mutations must fail without fabricating an owner completion.
python3 - "$work/gateway.s" "$work/unsafe-foreign.s" "$work/unsafe-self.s" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
old = ('        trnn    1,04                  ; skip wait when fatal-close is set\n'
       '        jrst    fs_provider_lock_sleep_v915\n'
       '        jrst    fs_provider_lock_refuse_v917')
new = ('        trnn    1,04                  ; skip wait when fatal-close is set\n'
       '        jrst    fs_provider_lock_sleep_v915\n'
       '        jrst    fs_provider_lock_sleep_v915')
assert source.count(old) == 1, 'v1088 negative control anchor'
Path(sys.argv[2]).write_text(source.replace(old, new, 1))
self_old = ('        came    0,proc_current_slot\n'
            '        jrst    fs_provider_lock_foreign_v1078\n'
            '        jrst    fs_provider_lock_refuse_v917')
self_new = ('        came    0,proc_current_slot\n'
            '        jrst    fs_provider_lock_foreign_v1078\n'
            '        jrst    fs_provider_lock_sleep_v915')
assert source.count(self_old) == 1, 'v1088 recursive negative control anchor'
Path(sys.argv[3]).write_text(source.replace(self_old, self_new, 1))
PY
for kind in foreign self; do
    if run_native "negative-$kind" "$work/unsafe-$kind.s"; then
        echo "v1088: unsafe $kind wait unexpectedly PASSED" >&2
        exit 1
    fi
done
echo 'v1088: live provider lease, recursive/fatal refusal, owner return, two unsafe negative controls PASS'
