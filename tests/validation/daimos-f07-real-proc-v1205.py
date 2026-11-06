#!/usr/bin/env python3
"""Snapshot real process descriptors, private BRKs and APR VM at OOM.

Applies only to the disposable v1150/v1159/v1203 kernel. The sampler
does not call MM, allocate memory, schedule, or change the guest stack.
"""

from pathlib import Path
import sys

p = Path(sys.argv[1]) / 'proc/syscall_dispatch_pdp6.s'
s = p.read_text()
anchor = ('daimos_f07_done_v1203:\n'
          '        move    6,fs_provider_ready')
assert s.count(anchor) == 1, 'v1205: no atomic MM snapshot finish'
code = '''daimos_f07_done_v1203:
        ; Read the stable process table while still on the same
        ; physical OOM decision; original lease is held by slot 6.
        aos     daimos_f07p_samples_v1205
        move    7,proc_high_slot
        movem   7,daimos_f07p_slots_v1205
        caile   7,0100             ; static 64-slot observation limit
        jrst    daimos_f07p_invalid_v1205
        ; AC0 is NOT an index register on the PDP-10. Use AC7 for
        ; all snapshot array indexes; AC0 holds non-indexed data.
        setz    7,
        move    6,proc_table
daimos_f07p_next_v1205:
        caml    7,daimos_f07p_slots_v1205
        jrst    daimos_f07p_done_v1205
        move    0,(6)              ; meta and UAREA mark
        movem   0,daimos_f07p_meta_v1205(7)
        move    0,1(6)             ; VM words,,physical APR base
        movem   0,daimos_f07p_vm_v1205(7)
        move    0,2(6)             ; scheduler state
        movem   0,daimos_f07p_sched_v1205(7)
        move    0,(6)
        trnn    0,0400000          ; stable u-area exists?
        jrst    daimos_f07p_no_uarea_v1205
        movem   6,daimos_f07p_cursor_v1205
        hlrz    6,(6)              ; stable u-area base in meta LH
        jumpe   6,daimos_f07p_invalid_v1205
        move    0,0407(6)          ; original floor,,logical BRK
        movem   0,daimos_f07p_brk_v1205(7)
        move    6,daimos_f07p_cursor_v1205
daimos_f07p_no_uarea_v1205:
        addi    6,3
        aoja    7,daimos_f07p_next_v1205
daimos_f07p_invalid_v1205:
        setom   daimos_f07p_error_v1205
daimos_f07p_done_v1205:
        move    6,fs_provider_ready'''
s = s.replace(anchor, code, 1)
s = '''        .globl proc_table
        .globl proc_high_slot
''' + s
s += '\n        .bss\n'
for sym in ('samples', 'slots', 'error', 'cursor'):
    name = 'daimos_f07p_%s_v1205' % sym
    s += '        .globl %s\n%s: .block 1\n' % (name, name)
for sym in ('meta', 'vm', 'sched', 'brk'):
    name = 'daimos_f07p_%s_v1205' % sym
    s += '        .globl %s\n%s: .block 0100\n' % (name, name)
p.write_text(s)
