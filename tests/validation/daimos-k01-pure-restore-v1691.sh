#!/bin/sh
# Native PDP-6 proof: failed post-zero PURE restore cannot resume process.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-pure-restore-v1691.XXXXXX")
if [ "${K01_KEEP_WORK:-0}" = 1 ]; then
    echo "K01 debug: $work"
else
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
swap="$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s"
{
    printf '%s\n' '.text' '.globl proc_swap_verify_restore_fail'
    sed -n '/^proc_swap_verify_restore_fail:$/,/^proc_swap_verify_ok:$/p' "$swap" | sed '$d'
    printf '%s\n' 'proc_swap_verify_ok: setz 1,' \
        'proc_swap_verify_return: popj 17,'
} > "$work/production.s"
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 120000 --timeout 20 \
        --workdir "$work/run-$name" --name "k01-pure-restore-$name-v1691" \
        --expect __test_exit=1 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-pure-restore-v1691.s" "$source" \
        > "$work/$name.log" 2>&1 || :
}
run production "$work/production.s"
python3 - "$work/run-production/k01-pure-restore-production-v1691.report.txt" \
    "$work/run-production/k01-pure-restore-production-v1691.labels" <<'PY'
from pathlib import Path
import re
import sys
report, labels = [Path(p).read_text() for p in sys.argv[1:]]
match = re.search(r'HALT instruction, PC: ([0-7]{6})', report)
assert match, 'PURE restore refusal did not halt'
symbols = dict(re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$', labels))
assert match.group(1) == symbols['proc_swap_verify_restore_lost_v1691']
PY
sed '/^        jumpn   1,proc_swap_verify_restore_lost_v1691$/d' \
    "$work/production.s" > "$work/unsafe.s"
run unsafe "$work/unsafe.s"
if grep -q 'HALT instruction, PC:' \
    "$work/run-unsafe/k01-pure-restore-unsafe-v1691.report.txt"; then
    echo 'K01 v1691: unsafe restore unexpectedly halted' >&2
    exit 1
fi
echo 'K01 v1691: native PDP-6 failed PURE restore halts, unsafe release mutant rejected PASS'
