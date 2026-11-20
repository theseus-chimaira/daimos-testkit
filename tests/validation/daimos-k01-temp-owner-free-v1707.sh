#!/bin/sh
# Source-linked PDP-6: no unpublished PIPE/D6FS/TSFS owner may be lost
# after MM refuses release with -4 or -5. Reject bypassed guards.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-temp-owner-free-v1707.XXXXXX")
if [ "${K01_KEEP_WORK:-0}" = 1 ]; then
    echo "K01 v1707 work=$work"
else
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 - "$DAIMOS_REPO/system/kernel" "$work" <<'PY'
from pathlib import Path
import sys

root, work = map(Path, sys.argv[1:])
pipe = (root / 'ipc/pipe.s').read_text()
d6fs = (root / 'fs/d6fs_runtime.s').read_text()
tsfs = (root / 'fs/tsfs_runtime.s').read_text()

pipe_part = pipe.split('pipe_create_free:\n', 1)[1].split(
    '; vnode_t pipe_fifo_open', 1)[0]
d6fs_part = d6fs.split('d6fs_mount_free:\n', 1)[1].split(
    'd6fs_mount_bad:\n', 1)[0]
tsfs_error = tsfs.split('tsfs_read_block_free:\n', 1)[1].split(
    'tsfs_read_words_io_error_v1538:', 1)[0]
# The native test must use the *production* owner value. Do not make a
# self-consistent fixture by silently substituting another owner ID.
assert tsfs.count('        .equ    TSFS_DECODE_OWNER,011\n') == 1

before_error = tsfs.split('tsfs_read_block_free:\n', 1)[0]
start_free = ('''        move    1,(17)
        movei   2,3
        movei   3,TSFS_DECODE_OWNER
        pushj   17,mm_free
''')
assert before_error.count(start_free) == 1
free_words = before_error[before_error.index(start_free):]
assert free_words.rstrip().endswith('jrst    tsfs_read_words_done')

cases = {
    'pipe': ('pipe_create_free:\n' + pipe_part.replace(
                 'pipe_create_fail:\n',
                 'pipe_create_fail:\n        aos     normal_calls_v1707\n', 1),
             'pipe_create_free', 2,
             '        movei   3,5\n', '''
call_release_v1707:
        push    17,010
        push    17,011
        movei   010,02000
        jrst    pipe_create_free
'''),
    'd6fs': ('d6fs_mount_free:\n' + d6fs_part, 'd6fs_mount_free', 3,
             '        movei   3,010\n', '''
call_release_v1707:
        push    17,[0]
        push    17,[0]
        push    17,[02000]
        jrst    d6fs_mount_free
d6fs_mount_done:
        aos     normal_calls_v1707
        sub     17,[3,,3]
        popj    17,
'''),
    'tsfs-error': ('tsfs_read_block_free:\n' + tsfs_error,
                   'tsfs_read_block_free', 1,
                   '        movei   3,TSFS_DECODE_OWNER\n', '''
call_release_v1707:
        push    17,[02000]
        jrst    tsfs_read_block_free
tsfs_read_words_fail:
        aos     normal_calls_v1707
        seto    1,
        popj    17,
'''),
    'tsfs-success': ('tsfs_success_free_v1707:\n' + free_words,
                     'tsfs_success_free_v1707', 1,
                     '        movei   3,TSFS_DECODE_OWNER\n', '''
call_release_v1707:
        push    17,[02000]
        jrst    tsfs_success_free_v1707
tsfs_read_words_fail:
        aos     normal_calls_v1707
        seto    1,
        popj    17,
tsfs_read_restart:
        aos     normal_calls_v1707
        seto    1,
        popj    17,
tsfs_read_words_done:
        aos     normal_calls_v1707
        seto    1,
        popj    17,
'''),
}

common = '''        .text
        .globl main
main:
        movei   1,0
        movem   1,mm_result_v1707
        pushj   17,reset_v1707
        pushj   17,call_release_v1707
        came    1,[-1]
        jrst    fail1_v1707
        move    1,normal_calls_v1707
        caie    1,1
        jrst    fail2_v1707
        skipn   invariant_calls_v1707
        jrst    test_invalid_v1707
        jrst    fail3_v1707
test_invalid_v1707:
        pushj   17,reset_v1707
        movni   1,4
        movem   1,mm_result_v1707
        pushj   17,call_release_v1707
        came    1,[-4]
        jrst    fail4_v1707
        pushj   17,check_invariant_v1707
        jumpn   1,fail5_v1707
        pushj   17,reset_v1707
        movni   1,5
        movem   1,mm_result_v1707
        pushj   17,call_release_v1707
        came    1,[-5]
        jrst    fail6_v1707
        pushj   17,check_invariant_v1707
        jumpn   1,fail7_v1707
        setz    1,
        popj    17,
reset_v1707:
        setzm   normal_calls_v1707
        setzm   invariant_calls_v1707
        setzm   free_calls_v1707
        setzm   bad_args_v1707
        popj    17,
check_invariant_v1707:
        skipn   normal_calls_v1707
        jrst    invariant_only_v1707
        seto    1,
        popj    17,
invariant_only_v1707:
        move    1,invariant_calls_v1707
        caie    1,1
        jrst    check_fail_v1707
        move    1,free_calls_v1707
        caie    1,1
        jrst    check_fail_v1707
        skipn   bad_args_v1707
        jrst    check_ok_v1707
check_fail_v1707:
        seto    1,
        popj    17,
check_ok_v1707:
        setz    1,
        popj    17,
        .globl mm_free
mm_free:
        caie    1,02000
        setom   bad_args_v1707
        caie    2,3
        setom   bad_args_v1707
'''
common_end = '''        aos     free_calls_v1707
        move    1,mm_result_v1707
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        ; Test-only witness. The production symbol is an unconditional HALT.
        aos     invariant_calls_v1707
        sub     17,[FRAME_WORDS,,FRAME_WORDS]
        popj    17,
fail1_v1707: movei 1,1
        popj 17,
fail2_v1707: movei 1,2
        popj 17,
fail3_v1707: movei 1,3
        popj 17,
fail4_v1707: movei 1,4
        popj 17,
fail5_v1707: movei 1,5
        popj 17,
fail6_v1707: movei 1,6
        popj 17,
fail7_v1707: movei 1,7
        popj 17,
        .bss
        .globl __test_exit
        .globl invariant_calls_v1707
        .globl free_calls_v1707
        .globl bad_args_v1707
        .globl mm_result_v1707
mm_result_v1707: .block 1
normal_calls_v1707: .block 1
invariant_calls_v1707: .block 1
free_calls_v1707: .block 1
bad_args_v1707: .block 1
__test_exit: .block 1
'''

for name, (snippet, label, frame, owner, entry) in cases.items():
    guard = '        jumpn   1,proc_swap_storage_invariant_v30\n'
    if name == 'tsfs-error':
        assert snippet.count(guard) == 1
    else:
        assert snippet.count(guard) == 1
    imports = ('.globl d6fs_mount_done\n' if name == 'd6fs'
               else ('.globl tsfs_read_words_fail\n'
                     '.globl kconst_1_1\n'
                     + ('.globl tsfs_read_restart\n'
                        '.globl tsfs_read_words_done\n'
                        if name == 'tsfs-success' else ''))
               if name.startswith('tsfs') else '')
    header = ('.text\n.globl normal_calls_v1707\n' + imports +
              '.equ FRAME_WORDS,%d\n' % frame +
              '.equ TSFS_DECODE_OWNER,011\n'
              '.globl ' + label + '\n')
    # Each snippet is directly extracted from the live production leaf.
    (work / (name + '-production.s')).write_text(header + snippet)
    (work / (name + '-unsafe.s')).write_text(
        header + snippet.replace(guard, '        move    0,0  ; unsafe dropped invariant guard\n', 1))
    args = ('        caie    3,011\n' if name.startswith('tsfs')
            else owner.replace('movei', 'caie'))
    args += '        setom   bad_args_v1707\n'
    fixture = ('.text\n.globl normal_calls_v1707\n' + imports +
               '.equ FRAME_WORDS,%d\n' % frame +
               '.equ TSFS_DECODE_OWNER,011\n' + common + args +
               common_end + '\n.text\n' + entry +
               '\n.data\nkconst_1_1: .word 1,,1\n')
    # D6FS and PIPE use a normal continuation from the extracted leaf.
    (work / (name + '-fixture.s')).write_text(fixture)
    print('v1707: source-linked', name, 'guard PASS')
PY

run()
{
    kind=$1
    variant=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 220000 --timeout 25 \
        --workdir "$work/run-$kind-$variant" \
        --name "daimos-k01-v1707-$kind-$variant" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$work/$kind-fixture.s" "$work/$kind-$variant.s" \
        > "$work/$kind-$variant.log" 2>&1
}
for kind in pipe d6fs tsfs-error tsfs-success; do
    run "$kind" production || {
        tail -55 "$work/$kind-production.log" >&2
        exit 1
    }
    if run "$kind" unsafe; then
        echo "K01 v1707: unguarded $kind cleanup unexpectedly passed" >&2
        exit 1
    fi
    grep -q '^FAIL:' "$work/$kind-unsafe.log" || {
        tail -45 "$work/$kind-unsafe.log" >&2
        exit 1
    }
    echo "K01 v1707: PDP-6 $kind MM owner retention and mutant PASS"
done
