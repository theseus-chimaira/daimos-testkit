#!/usr/bin/env python3
"""Source-linked contract for allocation-free PDP-6 fatal release leaves.

This is intentionally a *leaf* audit, not an OOM readiness certificate.
It verifies the reachable destructor bodies, while asynchronous foreign
owners, failure-injected FIFO OPEN rollback, and timer liveness remain open.
"""
from pathlib import Path
import os

root = Path(os.environ['DAIMOS_REPO']) / 'system/kernel'


def read(path):
    return (root / path).read_text()


def between(src, start, end):
    assert src.count(start) == 1, ('start anchor', start)
    body = src.split(start, 1)[1]
    assert end in body, ('end anchor', end)
    return body.split(end, 1)[0]


def never_alloc(name, body):
    for forbidden in ('pushj   17,mm_alloc', 'pushj 17,mm_alloc',
                      'pushj   17,backstore_alloc',
                      'pushj 17,backstore_alloc',
                      'pushj   17,memfs_data_ensure',
                      'pushj   17,pipe_alloc',
                      'mm_alloc(', 'mm_alloc_aligned(',
                      'backstore_alloc(', 'malloc(', 'calloc('):
        assert forbidden not in body, (name, forbidden)


proc = read('proc/proc_pdp6.s')
vm = read('proc/vm_pdp6.s')
swap = read('proc/vm_pdp6_swap.c')
memfs = read('fs/memfs_runtime.s')
memfs_data = read('fs/memfs_data_pdp6.s')
pipe = read('ipc/pipe.s')
dpy = read('drivers/dpy_io.s')
file_io = read('fs/file_runtime.s')
tty_c = read('proc/proc.c')

file_close = between(file_io, 'file_close_entry_v865:', '; int file_dup(')
pipe_close = between(pipe, 'pipe_close_ref:', '        .bss')
tty_release = between(proc, 'proc_tty_release_session:',
                      '; Remove only trailing FREE')
uarea_release = between(proc, 'proc_uarea_release:',
                        '* @brief Release TTY ownership')
vm_release = between(vm, 'vm_space_destroy:',
                     '* @brief Read executable words')
swap_detach = between(swap, 'proc_swap_detach(int slot)',
                      '/** Pin, write, free, and atomically publish')
xip_release = between(memfs, 'memfs_mres_xip_release:',
                      '; SPACE returns total')
xip_unpin = between(memfs_data, 'memfs_xip_unpin_base:',
                    '; int memfs_xip_owns_base(')
xip_owns = between(memfs_data, 'memfs_xip_owns_base:',
                   '; int memfs_data_ensure(')
dpy_stop = between(dpy, 'dpy_list_stop:',
                   '* @brief Update the retained Type-342')
tty_reset = between(tty_c, 'proc_tty_line_reset(unsigned int tty)',
                    '/**\n * Attempt to retire a canonical input buffer')

for name, part in (('FILE', file_close), ('PIPE', pipe_close),
                   ('TTY', tty_release), ('UAREA', uarea_release),
                   ('VM', vm_release), ('SWAP', swap_detach),
                   ('XIP', xip_release), ('XIP_UNPIN', xip_unpin),
                   ('XIP_OWNS', xip_owns), ('DPY_STOP', dpy_stop),
                   ('TTY_MM', tty_reset)):
    never_alloc(name, part)

assert 'pushj   17,pipe_close_ref' in file_close
assert 'pushj   17,vfs_sync' in file_close
assert 'dpy_close_words_call:' in file_close
assert 'jumpn   1,file_close_done' in file_close
assert 'pushj   17,mm_free' in pipe_close
assert 'jumpn   011,pipe_close_publish_v870' in pipe_close
assert pipe_close.index('pushj   17,mm_free') < pipe_close.index(
    'pipe_close_publish_v870:')

assert 'pushj   17,proc_tty_line_try_reset_v897' in tty_release
assert 'jumpn   1,proc_tty_release_fail_v1081' in tty_release
assert 'pushj   17,mm_free' in uarea_release
assert 'jumpn   1,proc_uarea_release_fail' in uarea_release

assert 'pushj   17,fs_provider_reg_call' in vm_release
assert 'pushj   17,mm_free' in vm_release
assert 'pushj   17,proc_swap_detach' in vm_release
assert 'jumpn   1,vm_space_destroy_fail' in vm_release
assert 'backstore_verify_allocated_v795(first, blocks)' in swap_detach
assert swap_detach.index('backstore_verify_allocated_v795') < swap_detach.index(
    'backstore_free(first, blocks)')

assert 'pushj   17,memfs_xip_owns_base' in xip_release
assert 'pushj   17,memfs_xip_unpin_base' in xip_release
assert 'pushj   17,mm_unpin' in xip_unpin
assert 'jumpn   1,memfs_xip_unpin_base_fail' in xip_unpin
assert 'memfs_xip_owns_base_yes:' in xip_owns

# The DPY zero-word STOP is reached before the mm_alloc site in the
# write/replace path. An orphan extent is checked and freed first.
dpy_write = between(dpy, 'dpy_write_words:', 'dpy_list_stop:')
assert 'jumpe 011,dpy_list_stop' in dpy_write
assert dpy_write.index('jumpe 011,dpy_list_stop') < dpy_write.index(
    'pushj 17,mm_alloc')
assert 'pushj 17,mm_free' in dpy_stop
assert 'movem 010,dpy_list_base' in dpy_stop
assert 'pushj   17,mm_free' in tty_reset or 'mm_free(base,' in tty_reset

# Detect the separate FIFO interrupted-open leak scenario; tracking
# its presence is not claiming a fix. The callback has no FILE retry
# owner on rejection and currently drops the return status.
open_abort = between(pipe, 'pipe_fifo_open_intr:', 'pipe_fifo_open_done:')
assert 'pushj   17,pipe_close_ref' in open_abort
assert 'jrst    pipe_fifo_open_bad' in open_abort
assert 'jumpn   1,' not in open_abort

print('v1083: direct fatal release leaves allocate no new MM/backing;')
print('v1083: PIPE/DPY/TTY/VM/XIP release contracts and FIFO OPEN risk PASS')
