#!/usr/bin/env python3
"""P0-A closed-call-graph contract for fatal FILE/HUP/VM release.

The analysis is limited to the currently supported built-in provider
dispatch tables. It deliberately does not certify the progress or
quiescence of an *already running* foreign provider (P0-B).
"""

import os
import re
from pathlib import Path

base = Path(os.environ['DAIMOS_REPO']) / 'system/kernel'
mode = os.environ.get('DAIMOS_V1087_NEGATIVE', '')


def read(path):
    return (base / path).read_text()


def section(source, begin, end):
    assert source.count(begin) == 1, ('anchor missing/duplicate', begin)
    data = source.split(begin, 1)[1]
    assert end in data, ('missing end', end)
    return data.split(end, 1)[0]


def instructions(body):
    body = re.sub(r'/\*.*?\*/', '', body, flags=re.S)
    return '\n'.join(line.split(';', 1)[0] for line in body.splitlines())


def calls(body):
    return set(re.findall(r'^\s*pushj\s+(?:17|017),\s*([A-Za-z_]\w*)',
                          instructions(body), re.I | re.M))


def closed(name, body, allowed, required=()):
    found = calls(body)
    assert found <= set(allowed), (name, 'new transitive edge',
                                    sorted(found - set(allowed)))
    assert set(required) <= found, (name, 'missing edge',
                                    sorted(set(required) - found))
    code = instructions(body)
    forbidden = ('mm_alloc', 'mm_alloc_aligned', 'backstore_alloc',
                 'malloc', 'calloc', 'memfs_data_ensure',
                 'pipe_alloc', 'fs_memory_reclaim')
    for needle in forbidden:
        assert not re.search(r'\b' + needle + r'\s*(?:\(|\b)', code), (
            name, 'allocation/reclaim', needle)


proc = read('proc/proc_pdp6.s')
run = read('proc/proc_run.s')
syscalls = read('proc/syscall_dispatch_pdp6.s')
clk = read('drivers/clk_io.s')
mach = read('proc/mach_user_pdp6.s')
fileio = read('fs/file_runtime.s')
vfs = read('fs/vfs.s')
fs = read('fs/fs_mres.s')
dtfs = read('fs/dtfs_runtime.s')
d6fs = read('fs/d6fs_runtime.s')
pipe = read('ipc/pipe.s')
dpy = read('drivers/dpy_io.s')
vm = read('proc/vm_pdp6.s')
swap = read('proc/vm_pdp6_swap.c')
tty_c = read('proc/proc.c')
mm = read('mm/mm_pdp6.s')
data = read('fs/memfs_data_pdp6.s')
memfs = read('fs/memfs_runtime.s')
bstore = read('storage/backstore.s')

if mode == 'file':
    fileio = fileio.replace('file_close_finish:\n',
                            'file_close_finish:\n        setzm   (010)\n', 1)
elif mode == 'hup':
    proc = proc.replace('proc_session_teardown_commit_v875:\n',
                        'proc_session_teardown_commit_v875:\n'
                        '        pushj   17,mm_alloc\n', 1)
elif mode == 'foreign':
    proc = proc.replace('        jumpn   1,proc_event_fatal_other_close_fail_v867',
                        '        jumpe   1,proc_event_fatal_other_close_fail_v867', 1)
elif mode == 'vfs':
    vfs = vfs.replace('vfs_sync:\n',
                      'vfs_sync:\n        pushj   17,mm_alloc\n', 1)
elif mode == 'sync':
    d6fs = d6fs.replace('d6fs_provider_sync:\n',
                        'd6fs_provider_sync:\n'
                        '        pushj   17,backstore_alloc\n', 1)
elif mode == 'pipe':
    pipe = pipe.replace('pipe_close_ref:\n',
                        'pipe_close_ref:\n        pushj   17,mm_alloc\n', 1)
elif mode == 'tty':
    proc = proc.replace('        jumpn   1,proc_finish_prevm_fail_v1081',
                        '        jumpe   1,proc_finish_prevm_fail_v1081', 1)
elif mode == 'vm':
    vm = vm.replace('vm_space_destroy:\n',
                    'vm_space_destroy:\n        pushj   17,backstore_alloc\n', 1)
elif mode == 'owner':
    proc = proc.replace('        jumpn   1,proc_fatal_close_wait_v995',
                        '        jumpe   1,proc_fatal_close_wait_v995', 1)
elif mode == 'discard':
    proc = proc.replace('        jumpn   1,proc_discard_prevm_fail_v1085',
                        '        jumpe   1,proc_discard_prevm_fail_v1085', 1)
elif mode == 'dpystop':
    dpy = dpy.replace('dpy_list_stop:\n',
                      'dpy_list_stop:\n        pushj 17,mm_alloc\n', 1)
else:
    assert mode == '', ('unsupported mutation', mode)

normal = section(syscalls, '%L66:', '%L67:')
assert normal.index('pushj   17,file_close_all') < normal.index(
    'pushj   17,proc_session_teardown') < normal.index(
    'jrst    proc_exit_current')
assert 'jumpn   1,native_sys_exit_hup_fail_v991' in normal
brk = section(syscalls, 'native_sys_brk:', '; Root may rebind')
expected_oom = os.environ.get('V1283_PRODUCTION_OOM_DEFAULT', '0')
assert expected_oom in ('0', '1'), 'invalid production OOM expectation'
assert ('PROC_OOM_BRK_ENABLED_V1000,' + expected_oom) in brk
assert 'native_sys_brk_oom_v1000:' in brk
assert 'jrst    proc_fatal_close_current_v879' in brk
assert 'camn    2,[-1]' in brk
assert 'jrst proc_fatal_close_current_v879' in clk
assert 'jrst proc_fatal_close_current_v879' in mach

owner = section(proc, 'proc_fatal_close_current_v879:',
                'proc_fatal_close_no_owner_v879:')
closed('fatal owner', owner,
       ('file_close_all', 'proc_session_teardown', 'proc_sleep_ticks'),
       ('file_close_all', 'proc_session_teardown', 'proc_sleep_ticks'))
assert owner.index('pushj   17,file_close_all') < owner.index(
    'pushj   17,proc_session_teardown') < owner.index(
    'jrst    proc_exit_current')
assert 'jumpn   1,proc_fatal_close_wait_v995' in owner
assert 'jumpe   1,proc_fatal_close_done_v879' in owner
assert 'jrst    proc_fatal_close_retry_v879' in owner
assert 'PROC_FATAL_CLOSE_BIT' in owner

all_close = section(fileio, 'file_close_all_at_v865:',
                    '; Shared bulk-word I/O validation')
closed('close all FD slots', all_close, ('file_close_entry_v865',),
       ('file_close_entry_v865',))
assert 'pushj   17,file_close_entry_v865' in all_close
assert 'jumpe   1,file_close_all_next' in all_close
assert 'seto    012' in all_close
assert 'move    1,012' in all_close
assert 'movem   4,1(011)' in all_close   # private fatal-close witness
assert 'move    011,1' in all_close or 'move    011,1' in fileio
assert 'move    1,011' in all_close   # use explicit target FD table

close = section(fileio, 'file_close_entry_v865:', '; int file_dup(')
closed('close one FD', close,
       ('file_node_from_fd', 'pipe_close_ref', 'vfs_sync', 'kret_zero'))
assert 'dpy_close_words_call:' in close
assert 'pushj   17,pipe_close_ref' in close
assert 'pushj   17,vfs_sync' in close
assert close.index('file_close_finish:') < close.index('setzm   (010)')
assert 'jumpn   1,file_close_done' in close.split('file_close_finish:', 1)[1].split(
    'setzm   (010)', 1)[0]

sync = section(vfs, 'vfs_sync:', '; One 128-word filesystem transfer workspace')
closed('VFS sync', sync, ())
assert 'movei   6,17' in sync
assert 'jrst    fs_provider_reg_call' in sync
assert 'cail    7,5' in sync and 'cail    7,7' in sync
gate = section(fs, 'fs_provider_reg_call:',
               '; KCORE memory-pressure bridge')
closed('FS register gateway', gate,
       ('proc_wait_event', 'proc_wakeup_event'))
assert 'jumpn   7,fs_provider_serialized' in gate
assert 'jrst    @fs_memfs_service_jump(7)' in gate
assert 'jrst    kret_neg5' in gate
assert gate.count('setom   fs_provider_ready') == 1
assert 'fs_provider_lock_foreign_v1078:' in gate
assert 'trnn    1,04' in gate
assert 'jrst    fs_provider_lock_refuse_v917' in gate
assert 'jrst    fs_provider_unlock' in gate

dtfs_sync = section(dtfs, 'dtfs_sync:', '; Shared clean DTC block-cache veneers')
closed('DTFS SYNC', dtfs_sync, ('dtfs_is_root', 'dtfs_is_file'))
assert 'jrst    kret_zero' in dtfs_sync
d6fs_sync = section(d6fs, 'd6fs_provider_sync:',
                    '; Publish the opposite A/B superblock')
closed('D6FS SYNC', d6fs_sync, ())
assert 'jrst    kret_zero' in d6fs_sync
assert '.word   dtfs_sync,,0' in dtfs
assert '.word   d6fs_provider_sync,,d6fs_provider_prepare_unmount' in d6fs

pipe_close = section(pipe, 'pipe_close_ref:', '        .bss')
closed('PIPE final release', pipe_close,
       ('pipe_fifo_unlink_object', 'mm_free', 'pipe_signal_event'))
assert 'jumpn   011,pipe_close_publish_v870' in pipe_close
assert pipe_close.index('pushj   17,mm_free') < pipe_close.index(
    'pipe_close_publish_v870:')
assert 'movem   010,pipe_fifo_head' in pipe_close
# Final MM failures return their true -4/-5 status through FILE.
# No refcount is published, and FIFO reinsertion uses AC3 so AC1
# still carries the allocator error into teardown diagnostics.
assert ('skipn   1(010)\n        jrst    pipe_close_done') in pipe_close
assert ('move    3,pipe_fifo_head\n'
        '        movem   3,(010)\n'
        '        movem   010,pipe_fifo_head\n'
        '        jrst    pipe_close_done') in pipe_close
assert 'pipe_close_bad:\n        seto    1,' in pipe_close
pipe_unlink = section(pipe, 'pipe_fifo_unlink_object:',
                      '; kword_t pipe_create(void)')
closed('FIFO unlink', pipe_unlink, ())
pipe_signal = section(pipe, 'pipe_signal_event:',
                      '; Arm and sleep interruptibly')
closed('PIPE wake signal', pipe_signal, ())
assert 'jrst    proc_wakeup_event' in pipe_signal
wakeup = section(proc, 'proc_wakeup_event:',
                 ';. Test-only process-private kernel stack watermarking')
closed('PIPE wake recipients', wakeup, ('proc_runq_add',))
dpy_stop = section(dpy, 'dpy_list_stop:',
                   '/**\n * @brief Update the retained Type-342')
closed('DPY STOP', dpy_stop, ('mm_free',))
assert 'jumpn 1,dpy_list_done' not in dpy_stop  # actual error uses reverse jump
assert 'movem 010,dpy_list_base' in dpy_stop

hup = section(proc, 'proc_session_teardown:',
              '/**\n * @brief Validate and deliver an event')
closed('session HUP', hup,
       ('proc_event_apply', 'proc_tty_line_try_reset_v897'),
       ('proc_event_apply', 'proc_tty_line_try_reset_v897'))
assert 'jumpn   1,proc_session_teardown_fail' in hup
assert 'proc_session_teardown_pending_v905:' in hup
assert 'PROC_FINALIZE_MARK_LH' in hup
assert 'camn    6,[-1]' in hup
assert hup.index('pushj   17,proc_event_apply') < hup.index(
    'pushj   17,proc_tty_line_try_reset_v897')

event = section(proc, 'proc_event_apply:', 'proc_event_nonfatal:')
closed('fatal event (self/foreign)', event,
       ('file_close_all', 'file_close_all_at_v865', 'proc_finish_slot',
        'proc_runq_add'))
runq = section(proc, 'proc_runq_add:', 'proc_runq_remove:')
closed('targeted fatal FS waiter queue', runq, ())
assert 'evt_def_fs_check_v1090:' in event
assert 'caie    6,fs_provider_wait_event_v917' in event
assert 'caie    6,PROC_STATE_SLEEP' in event
assert event.index('caie    6,fs_provider_wait_event_v917') < event.index(
    'pushj   17,proc_runq_add')
assert 'jrst    proc_fatal_close_current_v879' in event
assert 'jumpn   1,proc_event_fatal_other_close_fail_v867' in event
assert event.index('pushj   17,file_close_all_at_v865') < event.index(
    'jumpn   1,proc_event_fatal_other_close_fail_v867') < event.index(
    'pushj   17,proc_finish_slot')
assert 'proc_event_fatal_other_defer_term_v926:' in event
assert 'PROC_FATAL_CLOSE_BIT' in event and 'PROC_WAIT_LH_MASK' in event

finish = section(proc, 'proc_finish_slot:',
                 '/**\n * @brief Retry marked non-sleeping teardown')
closed('process finish', finish,
       ('proc_session_teardown', 'proc_tty_release_session',
        'vm_space_destroy', 'proc_uarea_release', 'proc_runq_remove',
        'proc_adopt_children_pdp6', 'proc_notify_parent',
        'proc_trim_high', 'proc_finish_mark_pending_v892'))
assert 'jrst    proc_finish_vm_retry_v997' in finish
assert 'jrst    proc_finish_uarea_retry_v881' in finish
assert 'jumpn   1,proc_finish_prevm_fail_v1081' in finish
assert 'jumpn   1,proc_finish_defer_uarea_v881' in finish
assert finish.index('pushj   17,proc_tty_release_session') < finish.index(
    'pushj   17,vm_space_destroy') < finish.index(
    'pushj   17,proc_uarea_release')

discard = section(proc, 'proc_slot_discard:',
                  '/**\n * @brief Release one process\'s stable executive u-area')
closed('unpublished RUN discard', discard,
       ('proc_scope_id', 'proc_tty_release_session',
        'vm_space_destroy', 'proc_uarea_release', 'proc_runq_remove',
        'proc_trim_high', 'proc_finish_mark_pending_v892'))
assert 'jumpn   1,proc_discard_prevm_fail_v1085' in discard
assert 'jumpn   1,proc_discard_defer_uarea_v892' in discard

# RUN may allocate its child's VM/u-area before all admission checks,
# but it publishes PIPE reference counts only after all FD mappings
# and does not take any further failing branch before SRUN publication.
# Therefore a rejected SIDL child never owns copied-but-uncounted FDs.
run_publish = section(run, 'proc_run_map_done:', 'proc_run_startup_failed:')
assert run_publish.index('pushj   17,pipe_add_refs') < run_publish.index(
    'movem   4,2(013)')
assert 'pushj   17,proc_slot_discard' in section(
    run, 'proc_run_claimed_bad:', 'proc_run_return:')

vm_destroy = section(vm, 'vm_space_destroy:',
                     '/**\n * @brief Read executable words')
closed('VM destroy', vm_destroy,
       ('proc_storage_expect_v30', 'fs_provider_reg_call',
        'mm_free', 'proc_swap_detach'))
assert 'jumpn   1,vm_space_destroy_fail' in vm_destroy
assert 'movei   6,026' in vm_destroy and 'movei   7,4' in vm_destroy
assert 'pushj   17,proc_swap_detach' in vm_destroy
assert 'proc_swap_detach(int slot)' in swap
swap_release = section(swap, 'proc_swap_detach(int slot)',
                       '/** Pin, write, free, and atomically publish')
closed('swap detach', swap_release, ())
assert swap_release.index('backstore_verify_allocated_v795(') < swap_release.index(
    'backstore_free(first, blocks)')
assert 'proc_storage_publish_v30(' in swap_release
assert 'proc_swap_records[slot].state = 0UL' in swap_release

scope = section(proc, 'proc_scope_id:', '; int proc_child_hierarchy')
closed('process scope', scope, ())
tty_has = section(proc, 'proc_tty_session_has:',
                  '/**\n * @brief Tear down a session leader')
closed('TTY session member scan', tty_has, ())
uarea = section(proc, 'proc_uarea_release:',
                '/**\n * @brief Release TTY ownership')
closed('u-area free', uarea, ('mm_free',))
assert 'jumpn   1,proc_uarea_release_fail' in uarea

for name, start, end, allowed in (
    ('runq unlink', 'proc_runq_remove:',
     '/**\n * @brief Return the stable physical u-area base', ()),
    ('parent notification', 'proc_notify_parent:',
     '; kword_t proc_scope_id', ('proc_runq_add',)),
    ('child adoption', 'proc_adopt_children_pdp6:',
     '/**\n * @brief Release heavy process resources',
     ('proc_notify_parent',))):
    closed(name, section(proc, start, end), allowed)

sleep = section(proc, 'proc_sleep_ticks:',
                '/**\n * @brief Sleep on a kernel event')
closed('owner backoff on own stack', sleep,
       ('proc_runq_remove', 'proc_slot_ptr'))
assert 'proc_current_slot' in sleep
assert 'proc_sched_kick' in sleep

tty_release = section(proc, 'proc_tty_release_session:',
                      '; Remove only trailing FREE')
closed('TTY last session', tty_release,
       ('proc_tty_session_has', 'proc_tty_line_try_reset_v897'))
assert 'jumpn   1,proc_tty_release_fail_v1081' in tty_release
tty_reset = section(tty_c, 'proc_tty_line_reset(unsigned int tty)',
                    '/** Change TTY input mode')
closed('TTY reset', tty_reset, ())
assert 'mm_free(base, MM_TYPE_KERNEL_DYNAMIC,' in tty_reset
assert tty_reset.index('mm_free(base,') < tty_reset.index(
    'proc_tty_line_base_set(tty, 0UL)')

xip = section(memfs, 'memfs_mres_xip_release:',
              '; SPACE returns total')
closed('XIP release', xip,
       ('memfs_xip_owns_base', 'memfs_xip_unpin_base'))
memfs_ref = section(data, 'memfs_xip_unpin_base:',
                    '; int memfs_xip_owns_base')
closed('XIP reference release', memfs_ref, ('mm_unpin',))
mm_free = section(mm, 'mm_free:', '; int mm_process_transfer_pinned')
closed('MM free', mm_free, ('mm_find_base', 'mm_delete'))
assert 'mm_free_busy:' in mm_free and 'mm_free_inval:' in mm_free
bitmap = section(bstore, 'backstore_verify_allocated_v795:',
                 '; int backstore_extend(first,old_blocks,new_blocks)')
closed('backstore verify', bitmap, ())
bitmap_release = section(bstore, 'backstore_free:', '        .bss')
closed('backstore free', bitmap_release, ())

print('v1087: BRK/APR/EXEC -> FILE/VFS/DTFS/D6FS/PIPE/DPY -> HUP graph PASS')
print('v1087: checked error/owner transitions -> TTY/VM/XIP/MM/SWAP/WAIT PASS')
print('v1087: no new MM/backstore allocation on bounded fatal release graph PASS')
print('v1087: foreign provider already in-flight remains P0-B (not certified)')
