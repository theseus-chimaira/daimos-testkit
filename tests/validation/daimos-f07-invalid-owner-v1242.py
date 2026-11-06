#!/usr/bin/env python3
"""Freeze owner/u-area context at a disposable invalid PDP-6 monitor UUO.

Requires the v1214 halt-after-trap instrumentation. This is diagnostic only:
no production branch, process identity, saved PC or fault policy changes.
"""

from pathlib import Path
import sys


FIELDS = ('faults', 'slot', 'process_ptr', 'meta', 'vm', 'sched',
          'uarea', 'ctx_pc', 'ctx_ksp', 'fdctl', 'saved_backing',
          'swap_record', 'syscall_save', 'user_sp', 'kernel_sp',
          'private_peak', 'idle_peak')


def inject(root):
    p = root / 'proc/mach_user_pdp6.s'
    source = p.read_text()
    anchor = '''        ; v1214 disposable-only trap state capture.
        halt 7
'''
    if source.count(anchor) != 1:
        raise ValueError('v1242: requires v1214 diagnostic UUO trap')
    body = '''        ; v1242: freeze first invalid-UUO owner before teardown.
        aos     daimos_f07i_faults_v1242
        move    5,proc_current_slot
        movem   5,daimos_f07i_slot_v1242
        move    5,proc_current_ptr
        movem   5,daimos_f07i_process_ptr_v1242
        jumpe   5,daimos_f07i_no_owner_v1242
        move    6,(5)
        movem   6,daimos_f07i_meta_v1242
        move    6,1(5)
        movem   6,daimos_f07i_vm_v1242
        move    6,2(5)
        movem   6,daimos_f07i_sched_v1242
        hlrz    5,(5)
        movem   5,daimos_f07i_uarea_v1242
        jumpe   5,daimos_f07i_no_owner_v1242
        move    6,020(5)
        movem   6,daimos_f07i_ctx_pc_v1242
        move    6,021(5)
        movem   6,daimos_f07i_ctx_ksp_v1242
        move    6,024(5)
        movem   6,daimos_f07i_fdctl_v1242
        move    6,0406(5)
        movem   6,daimos_f07i_saved_backing_v1242
daimos_f07i_no_owner_v1242:
        move    5,proc_swap_records
        jumpe   5,daimos_f07i_no_record_v1242
        add     5,proc_current_slot
        move    6,(5)
        movem   6,daimos_f07i_swap_record_v1242
daimos_f07i_no_record_v1242:
        move    5,mach_syscall_save
        movem   5,daimos_f07i_syscall_save_v1242
        move    5,mach_user_sp
        movem   5,daimos_f07i_user_sp_v1242
        move    5,mach_kernel_sp
        movem   5,daimos_f07i_kernel_sp_v1242
        move    5,proc_stack_highwater
        movem   5,daimos_f07i_private_peak_v1242
        move    5,kernel_idle_stack_highwater
        movem   5,daimos_f07i_idle_peak_v1242
        halt    7
'''
    source = source.replace(anchor, body, 1)
    source = '''        .globl proc_current_slot
        .globl proc_current_ptr
        .globl proc_swap_records
        .globl proc_stack_highwater
        .globl kernel_idle_stack_highwater
''' + ''.join('        .globl daimos_f07i_%s_v1242\n' % name
                for name in FIELDS) + source
    p.write_text(source)

    core = root / 'proc/proc_pdp6.s'
    text = core.read_text() + '\n        .bss\n'
    for name in FIELDS:
        sym = 'daimos_f07i_%s_v1242' % name
        text += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    core.write_text(text)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1242 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
