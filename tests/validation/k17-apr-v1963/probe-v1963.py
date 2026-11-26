#!/usr/bin/env python3
"""Native low-segment APR field and common VM boundary probe (PDP-6/KA10)."""
import argparse
from pathlib import Path
import re
import subprocess


def section(source, start, end):
    return source[source.index(start + ':\n'):source.index(end + ':\n')]


def main():
    p = argparse.ArgumentParser()
    for name in ('repo', 'prefix', 'work'):
        p.add_argument(name, type=Path)
    a = p.parse_args()
    a.work.mkdir(parents=True)
    source = (a.repo / 'system/kernel/proc/vm_pdp6.s').read_text()
    activate = section(source, 'vm_activate_current', 'vm_space_brk_current')
    # Include only the executable function, not the next documentation block.
    activate = activate[:activate.index('popj    17,') + len('popj    17,')]
    translate = section(source, 'vm_user_words', 'vm_user_mapping_hold')
    translate = translate[:translate.index('popj    17,') + len('popj    17,')]
    initial = section(source, 'vm_enter_initial_user_start', 'proc_exec_enter')
    assert re.search(r'move\s+0,1\(1\)\s*\n\s*sub\s+0,\[02000,,0\]', initial)
    fixture = a.work / 'probe-v1963.s'
    fixture.write_text('''        .text
        .globl start
        .globl __start
        .globl ready
        .globl vm_pdp6_apr
__start:
start:
        movei 17,stack
        movei 1,process
        movem 1,proc_current_ptr
        pushj 17,vm_activate_current
        movei 1,020
        pushj 17,vm_user_words
        movem 1,first
        movei 1,07777
        pushj 17,vm_user_words
        movem 1,last
        movei 1,010000
        pushj 17,vm_user_words
        movem 1,invalid
ready:
        halt
kret_zero:
        setz 1,
        popj 17,
''' + activate + '\n' + translate + '''
        .data
process: .word 0
        .word 010000,,020000
proc_current_ptr: .word 0
vm_pdp6_apr: .word 0
        .globl first
        .globl last
        .globl invalid
first: .word 0
last: .word 0
invalid: .word -1
        .bss
stack: .block 020
''')
    raw = a.work / 'probe-v1963.dxr'
    labels = a.work / 'probe-v1963.labels'
    deposit = a.work / 'probe-v1963.deposit'
    def tool(name):
        return str(a.prefix / 'bin' / name)
    subprocess.run([tool('das'), '-F', '-K', '-L', str(labels), '-O', str(raw), str(fixture)], check=True)
    subprocess.run([tool('dxrconvert'), '--simh', '--no-go', '-b', '1000', str(raw), str(deposit)], check=True)
    syms = {f[0]: int(f[1], 8) + 0o1000 for l in labels.read_text().splitlines() if len(f := l.split()) == 2}
    for cpu in ('pdp6', 'pdp10-ka'):
        for mode in (('oneseg', 'twoseg') if cpu == 'pdp10-ka' else ('',)):
            ini = a.work / (cpu + mode + '.ini')
            setup = 'set cpu 64k\n' + (('set cpu ' + mode + '\nset cpu nomaoff\n') if mode else '')
            ini.write_text(setup + deposit.read_text() + 'break %06o\ngo 1000\n' % syms['ready'] +
                           'examine RL\nexamine PL\n' + ('examine RH\nexamine PH\n' if mode else '') +
                           ''.join('examine %06o\n' % syms[n] for n in ('vm_pdp6_apr', 'first', 'last', 'invalid')) + 'exit\n')
            result = subprocess.run([tool(cpu), str(ini)], text=True, capture_output=True, timeout=15, check=True)
            log = result.stdout + result.stderr
            (a.work / (cpu + mode + '.log')).write_text(log)
            assert 'Breakpoint, PC: %06o' % syms['ready'] in log, log
            vals = {k: int(v, 8) for k, v in re.findall(r'^([0-7]+|RL|PL|RH|PH):\s+([0-7]+)', log, re.M)}
            assert vals['RL'] == 0o20000 and vals['PL'] == 0o7777, log
            if mode:
                assert vals['RH'] == 0 and vals['PH'] == 0o1777, log
            for n, expected in (('vm_pdp6_apr', 0o006000020000), ('first', 0o20020), ('last', 0o27777), ('invalid', 0)):
                assert vals[format(syms[n], 'o')] == expected, (n, log)
            print('PASS', cpu, mode, 'canonical low APR; aligned bounds; high fields disabled', flush=True)


if __name__ == '__main__':
    main()
