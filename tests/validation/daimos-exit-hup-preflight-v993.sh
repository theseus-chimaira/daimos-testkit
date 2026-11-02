#!/bin/sh
# Native PDP-6: real v991 EXIT dispatch branch, injectable HUP refusal.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}; export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=$(mktemp -d "$TMPDIR/daimos-exit-hup-preflight-v993.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/proc/syscall_dispatch_pdp6.s" "$work/entry.s" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
fragment=s.split('%L66:\n',1)[1].split('%L67:\n',1)[0]
assert 'native_sys_exit_hup_fail_v991:' in fragment
Path(sys.argv[2]).write_text('.text\n.globl exit_entry_v993\nexit_entry_v993:\n'+fragment)
PY
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
 --exec-mode step --start 1000 --step-limit 100000 --timeout 20 \
 --workdir "$work/run" --name exit-hup-v993 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" "$work/entry.s" \
 "$self/daimos-exit-hup-preflight-v993.s" > "$work/log" 2>&1 || {
 tail -50 "$work/log" >&2; exit 1;
 }
echo 'v993: owner EXIT HUP refusal and successful retry control flow PASS'
