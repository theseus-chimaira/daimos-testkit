#!/usr/bin/env python3
"""Exercise native KA10 instruction trap using the production entry."""
import argparse
from pathlib import Path
import re
import subprocess


def main():
    p = argparse.ArgumentParser()
    for name in ('repo', 'prefix', 'work'):
        p.add_argument(name, type=Path)
    a = p.parse_args()
    a.work.mkdir(parents=True)
    source = (a.repo / 'system/kernel/proc/mach_user_pdp6.s').read_text()
    start = source.index('        .globl mach_unassigned_save')
    end = source.index('        .endif', start)
    handler = source[start:end]
    asm = a.work / 'trap-v1964.s'
    asm.write_text('''        .text
        .globl __start
        .globl start
        .globl exec_case
        .globl exec_fault
        .globl mach_kernel_sp
        .globl passed
__start:
start:
        move 1,[jsr mach_unassigned_save]
        movem 1,061
        move 1,[0,,020000]
        movem 1,apr_word
        datao 0,apr_word
        movei 17,01000
        jrst 1,020
exec_case:
        move 1,[jsr mach_unassigned_save]
        movem 1,061
exec_fault:
        .word 0105000000000
        halt
''' + handler + '''
proc_fatal_close_current_v879:
        movem 1,status
        movem 17,saved_sp
passed:
        halt passed
        .data
        .globl status
        .globl saved_sp
mach_kernel_sp: .word 03000
apr_word: .word 0
status: .word 0
saved_sp: .word 0
''')
    raw = a.work / 'trap.dxr'
    labels = a.work / 'trap.labels'
    dep = a.work / 'trap.deposit'
    def tool(n):
        return str(a.prefix / 'bin' / n)
    subprocess.run([tool('das'), '-F', '-K', '-L', str(labels), '-O', str(raw), str(asm)], check=True)
    subprocess.run([tool('dxrconvert'), '--simh', '--no-go', '-b', '1000', str(raw), str(dep)], check=True)
    syms = {f[0]: int(f[1], 8)+0o1000 for l in labels.read_text().splitlines() if len(f := l.split()) == 2}
    for mode in ('user', 'exec'):
        entry = syms['start' if mode=='user' else 'exec_case']
        ini = a.work / (mode+'.ini')
        ini.write_text('set cpu 64k\nset cpu oneseg\nset cpu nomaoff\n'+dep.read_text()+
                       'deposit 20020 105000000000\n'+f'go {entry:06o}\n'+
                       'examine 060\n'+''.join(f'examine {syms[n]:06o}\n' for n in ('status','saved_sp','mach_unassigned_save'))+'exit\n')
        r = subprocess.run([tool('pdp10-ka'),str(ini)], capture_output=True,text=True,timeout=15,check=True)
        log = r.stdout+r.stderr
        (a.work/(mode+'.log')).write_text(log)
        vals={int(n,8):int(v,8) for n,v in re.findall(r'^([0-7]+):\s+([0-7]+)',log,re.M)}
        assert vals[0o60] == 0o105000000000,log
        if mode=='user':
            assert vals[syms['status']]==0o400001 and vals[syms['saved_sp']]==0o3000, log
            assert 'HALT instruction, PC: %06o'%syms['passed'] in log, log
            assert vals[syms['mach_unassigned_save']] & (0o10000 << 18), log
        else:
            assert vals[syms['status']]==0 and vals[syms['saved_sp']]==0, log
            assert 'HALT instruction, PC: 000000' in log, log
            assert vals[syms['mach_unassigned_save']] and not vals[syms['mach_unassigned_save']] & (0o10000 << 18), log
        print('PASS KA10',mode,'unassigned instruction trap',flush=True)


if __name__ == '__main__':
    main()
