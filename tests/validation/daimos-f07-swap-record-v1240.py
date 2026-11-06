#!/usr/bin/env python3
"""Count swap-service admission rejects and snapshot PID 1/5 records.

Requires the disposable v1238 scheduler snapshot; modifies no production
source. Rejected early-exit branches are counted without changing policy.
"""

from pathlib import Path
import sys


FIELDS = ('record_base', 'pid1_record', 'pid5_record', 'pid1_backing',
          'pid5_backing', 'reject_state', 'reject_vm', 'reject_record',
          'reject_transition', 'pop_clear')


def once(source, before, after):
    if source.count(before) != 1:
        raise ValueError('v1240: ambiguous/moved source anchor: ' + before[:55])
    return source.replace(before, after, 1)


def inject(root):
    core = root / 'proc/proc_pdp6.s'
    source = core.read_text() + '\n        .bss\n'
    for name in FIELDS:
        sym = 'daimos_f07z_%s_v1240' % name
        source += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    core.write_text(source)

    p = root / 'proc/proc_swap_pdp6.s'
    source = p.read_text()
    anchor = '''daimos_f07q_no_table_v1238:
        pop     17,7
'''
    snapshot = '''daimos_f07q_no_table_v1238:
        move    7,proc_swap_records
        movem   7,daimos_f07z_record_base_v1240
        jumpe   7,daimos_f07z_no_records_v1240
        move    7,1(7)
        movem   7,daimos_f07z_pid1_record_v1240
        move    7,proc_swap_records
        move    7,5(7)
        movem   7,daimos_f07z_pid5_record_v1240
daimos_f07z_no_records_v1240:
        move    7,proc_table
        addi    7,3
        hlrz    7,(7)
        jumpe   7,daimos_f07z_no_pid1_v1240
        move    7,PROC_SWAP_BACKING_OFFSET(7)
        movem   7,daimos_f07z_pid1_backing_v1240
daimos_f07z_no_pid1_v1240:
        move    7,proc_table
        addi    7,017
        hlrz    7,(7)
        jumpe   7,daimos_f07z_no_pid5_v1240
        move    7,PROC_SWAP_BACKING_OFFSET(7)
        movem   7,daimos_f07z_pid5_backing_v1240
daimos_f07z_no_pid5_v1240:
        pop     17,7
'''
    # PID 5 descriptor starts 3*5 = 017 octal words after proc_table.
    source = once(source, anchor, snapshot)

    # All checks below are within the service entry gate, not the many
    # subsequent transaction validators that share the same branch text.
    start = source.index('proc_swap_mres_service_v481:\n')
    end = source.index('proc_swap_service_pressure:\n', start)
    gate = source[start:end]
    checks = (
        ('reject_state', '''        caie    3,PROC_STATE_RUN
        jrst    proc_swap_service_pop_clear
'''),
        ('reject_vm', '''        trne    3,0777777
        jrst    proc_swap_service_pop_clear
'''),
        ('reject_record', '''        skipn   (3)
        jrst    proc_swap_service_pop_clear
'''),
        ('reject_transition', '''        trne    3,PROC_TRANSITION_RH
        jrst    proc_swap_service_pop_clear
'''),
    )
    for name, anchor in checks:
        gate = once(gate, anchor,
                    anchor.replace('jrst    proc_swap_service_pop_clear',
                                   'jrst    f07z_%s_v1240' %
                                   name.replace('reject_', '')))
    source = source[:start] + gate + source[end:]
    source = once(source, 'proc_swap_service_pop_clear:\n',
                  'proc_swap_service_pop_clear:\n'
                  '        aos     daimos_f07z_pop_clear_v1240\n')
    redirects = ''
    for name, _ in checks:
        redirects += '''f07z_%s_v1240:
        aos     daimos_f07z_%s_v1240
        jrst    proc_swap_service_pop_clear
''' % (name.replace('reject_', ''), name)
    source = once(source, 'proc_swap_service_pressure:\n',
                  redirects + 'proc_swap_service_pressure:\n')
    source = ''.join('        .globl daimos_f07z_%s_v1240\n' % name
                     for name in FIELDS) + source
    p.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1240 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
