#!/usr/bin/env python3
"""Fail-closed source contract for both PI6-masked slot-0 entry paths.

P0-C is deliberately narrower than the general OOM resource-lifetime
proof. This test checks which routines are *reachable* while PI6 is
inhibited, rather than demanding that every process teardown be free
of sleeps even on an ordinary private process stack.
"""
import os
from pathlib import Path
import re

root = Path(os.environ['DAIMOS_REPO']) / 'system/kernel'


def read(name):
    return (root / name).read_text()


proc = read('proc/proc_pdp6.s')
syscall = read('proc/syscall_dispatch_pdp6.s')
procc = read('proc/proc.c')
vm = read('proc/vm_pdp6.s')
swap = read('proc/vm_pdp6_swap.c')
fs = read('fs/fs_mres.s')
memfs = read('fs/memfs_runtime.s')
data = read('fs/memfs_data_pdp6.s')
mm = read('mm/mm_pdp6.s')
backstore = read('storage/backstore.s')
storage = read('proc/proc_storage_runtime_v30.s')

negative = os.environ.get('DAIMOS_V1086_NEGATIVE', '')
if negative == 'exit':
    proc = proc.replace(
        'movem   6,PROC_FINALIZE_OFFSET(5)\n        movei   6,PROC_TRANSITION_RH',
        'setzm   PROC_FINALIZE_OFFSET(5)\n        movei   6,PROC_TRANSITION_RH', 1)
elif negative == 'gateway':
    fs = fs.replace('jumpn   7,fs_provider_serialized',
                    'jumpe   7,fs_provider_serialized', 1)
elif negative == 'xip':
    memfs = memfs.replace('memfs_mres_xip_release:\n',
                          'memfs_mres_xip_release:\n'
                          '        pushj   17,proc_wait_event\n', 1)
elif negative == 'idle':
    proc = proc.replace('        pushj   17,proc_finish_service_v881\n',
                        '        pushj   17,proc_swap_service_one\n'
                        '        pushj   17,proc_finish_service_v881\n', 1)
elif negative == 'self':
    proc = proc.replace('        jrst    proc_fatal_close_current_v879\n',
                        '        jrst    proc_exit_current\n', 1)
elif negative == 'tty':
    proc = proc.replace('proc_tty_release_session:\n',
                        'proc_tty_release_session:\n'
                        '        pushj   17,proc_wait_event\n', 1)
elif negative == 'swap':
    swap = swap.replace('proc_swap_detach(int slot)\n{',
                        'proc_swap_detach(int slot)\n{\n'
                        '        backstore_read(0, 0, 0);', 1)
else:
    assert not negative, 'unsupported negative mutation'


def part(src, start, end):
    assert src.count(start) == 1, ('missing or duplicate start', start)
    tail = src.split(start, 1)[1]
    assert end in tail, ('missing end', end)
    return tail.split(end, 1)[0]


def call_targets(src):
    return set(re.findall(r'^\s*pushj\s+17,([A-Za-z_]\w*)', src,
                          re.M | re.I))


def only_calls(name, body, allowed):
    actual = call_targets(body)
    assert actual <= set(allowed), (name, 'unexpected calls',
                                    sorted(actual - set(allowed)))


def no_wait(name, body):
    banned = ('proc_wait_event', 'proc_wait_child', 'proc_sleep_ticks',
              'proc_swap_service_one', 'backstore_read', 'backstore_write',
              'blockset_direct_tail_read', 'blockset_direct_tail_write',
              'mm_alloc', 'mm_alloc_aligned', 'memfs_data_ensure')
    code = re.sub(r'/\*.*?\*/', '', body, flags=re.S)
    code = re.sub(r';[^\n]*', '', code)
    edges = call_targets(code)
    edges.update(re.findall(r'^\s*jrst\s+([A-Za-z_]\w*)', code,
                            re.M | re.I))
    for symbol in banned:
        assert symbol not in edges, (name, symbol)
        assert not re.search(r'\b' + symbol + r'\s*\(', code), (name, symbol)


# The periodic slot-0 reaper masks PI6 around only the marked retry
# walker. It never invokes disk-backed swap-in until PI6 has returned.
idle = part(proc, 'proc_idle_loop:', 'proc_idle_loop_end:')
masked = part(idle, 'cono    0004,01002', 'cono    0004,02002')
assert 'pushj   17,proc_finish_service_v881' in masked
assert 'pushj   17,proc_swap_service_one' not in masked
assert 'pushj   17,proc_swap_service_one' in idle.split(
    'cono    0004,02002', 1)[1]
assert 'proc_idle_swap_v881:' in idle.split('cono    0004,02002', 1)[1]
assert 'proc_finish_backoff_advance_v885' in masked

service = part(proc, 'proc_finish_service_v881:',
               '/**\n * @brief Discard an uncommitted RUN slot')
only_calls('idle reaper', service,
           ('proc_slot_discard', 'proc_finish_slot', 'proc_has_live_user'))
no_wait('idle reaper', service)
for guard in ('PROC_SIDL_DISCARD_VM_RH', 'PROC_FINALIZE_PREVM_LH',
              'PROC_FINALIZE_MARK_LH', 'proc_finish_service_check_v881:',
              'proc_finish_service_discard_v892:'):
    # SIDL marker is described in source and encoded as bit 02.
    if guard == 'PROC_SIDL_DISCARD_VM_RH':
        assert 'trnn    4,02' in service
    else:
        assert guard in service, guard

# There is a second PI6-masked entry: EXIT switches stacks and invokes
# the C finalizer. HUP preflight MUST be completed before that entry.
normal_exit = part(syscall, '%L66:', '%L67:')
assert normal_exit.index('pushj   17,file_close_all') < normal_exit.index(
    'pushj   17,proc_session_teardown') < normal_exit.index(
    'jrst    proc_exit_current')
assert 'jumpn   1,native_sys_exit_hup_fail_v991' in normal_exit
fatal_owner = part(proc, 'proc_fatal_close_current_v879:',
                   'proc_fatal_close_no_owner_v879:')
assert fatal_owner.index('pushj   17,file_close_all') < fatal_owner.index(
    'pushj   17,proc_session_teardown') < fatal_owner.index(
    'jrst    proc_exit_current')
assert 'jumpe   1,proc_fatal_close_done_v879' in fatal_owner
assert 'pushj   17,proc_sleep_ticks' in fatal_owner  # PRIVATE stack only
self_fatal = part(proc, 'proc_event_fatal:', 'proc_fatal_self_fail_v868:')
assert 'jrst    proc_fatal_close_current_v879' in self_fatal
assert 'jrst    proc_exit_current' not in self_fatal

handoff = part(proc, 'proc_exit_current:',
               '/**\n * @brief Finish an irreversible user fault')
for fragment in ('pushj   17,mach_pi_disable',
                 'movsi   6,PROC_FINALIZE_MARK_LH+PROC_FINALIZE_PREVM_LH',
                 'movem   6,PROC_FINALIZE_OFFSET(5)',
                 'iorm    6,(4)',
                 'move    17,mach_kernel_stack_base',
                 'cono    0004,01002',
                 'pushj   17,proc_exit_finish'):
    assert fragment in handoff, fragment
assert handoff.index('pushj   17,mach_pi_disable') < handoff.index(
    'movem   6,PROC_FINALIZE_OFFSET(5)') < handoff.index(
    'move    17,mach_kernel_stack_base') < handoff.index(
    'cono    0004,01002') < handoff.index(
    'pushj   17,proc_exit_finish')
exit_c = part(procc, 'proc_exit_finish(int status)',
              '/**' if '/**' in procc.split('proc_exit_finish(int status)', 1)[1]
              else '\n}')
assert 'proc_current_slot = 0UL;' in exit_c
assert 'proc_finish_slot_owner_v932' in exit_c

# The marked EXIT can enter only the PREVM or post-VM finalizer,
# bypassing HUP even when VM still exists.
finish = part(proc, 'proc_finish_slot:',
              '/**\n * @brief Retry marked non-sleeping teardown')
phase = part(finish, 'proc_finish_ids:', 'proc_finish_hup_new_v997:')
for fragment in ('tlnn    4,PROC_FINALIZE_MARK_LH',
                 'jrst    proc_finish_hup_new_v997',
                 'tlne    4,PROC_FINALIZE_PREVM_LH',
                 'jrst    proc_finish_vm_retry_v997',
                 'jrst    proc_finish_uarea_retry_v881'):
    assert fragment in phase
assert phase.index('tlnn    4,PROC_FINALIZE_MARK_LH') < phase.index(
    'jrst    proc_finish_hup_new_v997')
assert finish.count('pushj   17,proc_session_teardown') == 1
only_calls('marked finish', finish,
           ('proc_session_teardown', 'proc_tty_release_session',
            'vm_space_destroy', 'proc_uarea_release', 'proc_runq_remove',
            'proc_adopt_children_pdp6', 'proc_notify_parent',
            'proc_trim_high', 'proc_finish_mark_pending_v892'))

discard = part(proc, 'proc_slot_discard:',
               '/**\n * @brief Release one process\'s stable executive u-area')
only_calls('SIDL rollback', discard,
           ('proc_scope_id', 'proc_tty_release_session',
            'vm_space_destroy', 'proc_uarea_release',
            'proc_runq_remove', 'proc_trim_high',
            'proc_finish_mark_pending_v892'))
no_wait('SIDL rollback', discard)
assert discard.index('pushj   17,proc_tty_release_session') < discard.index(
    'pushj   17,vm_space_destroy')
assert 'jumpn   1,proc_discard_prevm_fail_v1085' in discard

# All the actual teardown leaves reachable through the two marked
# finalizers are non-sleeping. No user FILE close/HUP or clock gate.
tty = part(proc, 'proc_tty_release_session:', '; Remove only trailing FREE')
only_calls('TTY release', tty,
           ('proc_tty_session_has', 'proc_tty_line_try_reset_v897'))
no_wait('TTY release', tty)
tty_c = part(procc, 'proc_tty_line_reset(unsigned int tty)',
             '/** Change TTY input mode')
assert 'mm_free(base, MM_TYPE_KERNEL_DYNAMIC,' in tty_c
assert 'proc_tty_line_base_set(tty, 0UL)' in tty_c
assert 'proc_tty_line_try_reset_v897(unsigned int tty)' in tty_c
no_wait('TTY C release', tty_c)

uarea = part(proc, 'proc_uarea_release:',
             '/**\n * @brief Release TTY ownership')
only_calls('U-area release', uarea, ('mm_free',))
no_wait('U-area release', uarea)

vm_destroy = part(vm, 'vm_space_destroy:',
                  '/**\n * @brief Read executable words')
only_calls('VM destroy', vm_destroy,
           ('proc_storage_expect_v30', 'fs_provider_reg_call',
            'mm_free', 'proc_swap_detach'))
no_wait('VM destroy', vm_destroy)
assert 'movei   6,026' in vm_destroy
assert 'movei   7,4' in vm_destroy

gateway = part(fs, 'fs_provider_reg_call:', 'fs_provider_serialized:')
assert 'subi    7,4' in gateway
assert 'jumpn   7,fs_provider_serialized' in gateway
assert 'jrst    @fs_memfs_service_jump(7)' in gateway
assert gateway.index('jumpn   7,fs_provider_serialized') < gateway.index(
    'jrst    @fs_memfs_service_jump(7)')
assert 'proc_wait_event' not in call_targets(gateway)
memfs_dispatch = part(memfs, 'memfs_mres_reg_dispatch:',
                      '; AC1=vnode, AC2=')
assert 'cain    6,026' in memfs_dispatch
assert 'jrst    memfs_mres_xip_release' in memfs_dispatch
assert memfs_dispatch.index('cain    6,026') < memfs_dispatch.index(
    'jrst    memfs_mres_xip_release') < memfs_dispatch.index(
    'jrst    fs_mres_context_vector_dispatch')
xip_release = part(memfs, 'memfs_mres_xip_release:',
                   '; SPACE returns total')
only_calls('MEMFS XIP release', xip_release,
           ('memfs_xip_owns_base', 'memfs_xip_unpin_base'))
no_wait('MEMFS XIP release', xip_release)
xip_unpin = part(data, 'memfs_xip_unpin_base:',
                 '; int memfs_xip_owns_base')
only_calls('MEMFS XIP unpin', xip_unpin, ('mm_unpin',))
no_wait('MEMFS XIP unpin', xip_unpin)
xip_owns = part(data, 'memfs_xip_owns_base:',
                '; int memfs_data_ensure')
only_calls('MEMFS XIP ownership lookup', xip_owns, ())
no_wait('MEMFS XIP ownership lookup', xip_owns)

mmfree = part(mm, 'mm_free:', '; int mm_process_transfer_pinned')
only_calls('MM free', mmfree, ('mm_find_base', 'mm_delete'))
no_wait('MM free', mmfree)
mmpin = part(mm, 'mm_pin_adjust:', '        .bss')
only_calls('MM pin/unpin', mmpin, ('mm_find_base',))
no_wait('MM pin/unpin', mmpin)

swap_detach = part(swap, 'proc_swap_detach(int slot)',
                   '/** Pin, write, free, and atomically publish')
for name in ('backstore_free', 'proc_storage_publish_v30'):
    assert name + '(' in swap_detach
assert 'backstore_free(first, blocks) != 0' in swap_detach
no_wait('swap detach C', swap_detach)
assert 'backstore_read(' not in swap_detach
assert 'backstore_write(' not in swap_detach
assert 'mm_alloc(' not in swap_detach
bitmap_free = part(backstore, 'backstore_free:', '        .bss')
bitmap_verify = part(backstore, 'backstore_verify_allocated_v795:',
                     '; int backstore_extend(first,old_blocks,new_blocks)')
for name, body in (('bitmap free', bitmap_free),
                   ('bitmap verifier', bitmap_verify)):
    only_calls(name, body, ('backstore_verify_allocated_v795',)
               if name == 'bitmap free' else ())
    no_wait(name, body)
storage_publication = part(storage, 'proc_storage_expect_v30:',
                           '; int proc_storage_exchange_modes_v778')
only_calls('swap storage mode', storage_publication,
           ('proc_storage_expect_v30',))
no_wait('swap storage mode', storage_publication)

for name, start, end, allowed in (
    ('notify parent', 'proc_notify_parent:', '; kword_t proc_scope_id',
     ('proc_runq_add',)),
    ('adopt children', 'proc_adopt_children_pdp6:',
     '/**\n * @brief Release heavy process resources',
     ('proc_notify_parent',)),
    ('process scope', 'proc_scope_id:', '; int proc_child_hierarchy', ())):
    body = part(proc, start, end)
    only_calls(name, body, allowed)
    no_wait(name, body)

print('v1086: idle and EXIT PI6 masks; pre-HUP marker and self-fatal owner route PASS')
print('v1086: SIDL/VM/TTY/MEMFS-XIP/MM/bitmap/notify callback closure PASS')
print('v1086: no slot-0 clock wait or hardware transfer reachable in marked teardown PASS')
