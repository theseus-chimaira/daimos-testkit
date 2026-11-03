#!/bin/sh
# v1099: real PDP-6 PIPE final-close MM_BUSY/-5 vs MM_INVAL/-4.
# Both anonymous and named FIFO owners must survive the returned failure.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pipe-typed-v1099.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1099 work: $work"; fi' EXIT HUP INT TERM
{
    printf '.text\n.globl file_close_entry_v865\n'
    sed -n '/^file_close_entry_v865:$/,/^; int file_dup(int fd)/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    printf '.globl pipe_fifo_unlink_object\n'
    sed -n '/^pipe_fifo_unlink_object:$/,/^; kword_t pipe_create/p' \
        "$DAIMOS_REPO/system/kernel/ipc/pipe.s" | sed '$d'
    printf '.globl pipe_close_ref\n'
    sed -n '/^pipe_close_ref:$/,/^[[:space:]]*\.bss$/p' \
        "$DAIMOS_REPO/system/kernel/ipc/pipe.s" | sed '$d'
} > "$work/production.s"
python3 - "$self/daimos-pipe-close-v870.s" "$work" <<'PY'
from pathlib import Path
import sys

fixture = Path(sys.argv[1]).read_text()
work = Path(sys.argv[2])
assert fixture.count(' camn 1,[-1]') == 2
fixture = fixture.replace(' camn 1,[-1]', ' camn 1,[-5]', 1)
fixture = fixture.replace(' camn 1,[-1]', ' camn 1,[-4]', 1)
assert fixture.count('fifo_fail:\n movei 1,1') == 1
fixture = fixture.replace('fifo_fail:\n movei 1,1',
                          'fifo_fail:\n movei 1,4')
assert fixture.count('__fail_free: .word 1') == 1
fixture = fixture.replace('__fail_free: .word 1', '__fail_free: .word 5')
old = ' seto 1,\n popj 17,\nmm_ok:'
new = ' move 1,__fail_free\n movn 1,1\n popj 17,\nmm_ok:'
assert fixture.count(old) == 1
fixture = fixture.replace(old, new)
(work / 'fixture.s').write_text(fixture)

production = (work / 'production.s').read_text()
assert 'pipe_close_free_v870:' in production
assert 'jumpe   1,pipe_close_ok' in production
assert 'move    3,pipe_fifo_head' in production
assert 'movem   3,(010)' in production
assert 'movem   010,pipe_fifo_head' in production
assert production.count('jrst    pipe_close_done') >= 2

# Each mutant deliberately violates a different policy. The same native
# program must reject a wrong error status or a lost surviving owner.
mutants = {
    'anon-error': (
        '        skipn   1(010)\n        jrst    pipe_close_done',
        '        skipn   1(010)\n        jrst    pipe_close_bad'),
    'fifo-error': (
        '        movem   010,pipe_fifo_head\n'
        '        jrst    pipe_close_done',
        '        movem   010,pipe_fifo_head\n'
        '        jrst    pipe_close_bad'),
    'fifo-owner': (
        '        movem   010,pipe_fifo_head\n'
        '        jrst    pipe_close_done',
        '        setzm   pipe_fifo_head\n'
        '        jrst    pipe_close_done'),
    'premature-refs': (
        '        jumpn   011,pipe_close_publish_v870',
        '        jrst    pipe_close_publish_v870'),
}
for name, (old, new) in mutants.items():
    assert production.count(old) == 1, name + ' source anchor drift'
    (work / ('unsafe-' + name + '.s')).write_text(
        production.replace(old, new, 1))
PY
run_case() {
    name=$1
    leaf=$2
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
        --workdir "$work/run-$name" --name "pipe-typed-v1099-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$leaf" "$work/fixture.s" \
        > "$work/log-$name" 2>&1; then
        return 0
    fi
    return 1
}
if ! run_case positive "$work/production.s"; then
    tail -65 "$work/log-positive" >&2
    exit 1
fi
for name in anon-error fifo-error fifo-owner premature-refs; do
    if run_case "$name" "$work/unsafe-$name.s"; then
        echo "v1099: unsafe $name variant unexpectedly passed" >&2
        exit 1
    fi
done
echo 'v1099: typed -5/-4 final PIPE close, FD/FIFO refs and four unsafe mutants PASS'
