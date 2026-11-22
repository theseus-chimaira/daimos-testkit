#!/usr/bin/env python3
"""Physical K04 child PREVM pin during fatal WAITing-parent death.

Uses a disposable v1797 PDP-6 guest, real mm_pin/mm_unpin, two ROOT
consoles, KILL of the parent and a guest-commanded clean HALT.
"""
from pathlib import Path
import os
import pexpect
import re
import subprocess
import sys
import time


tmp = Path(os.environ.get('TMPDIR', str(Path.home() / 'tmp')))
root = tmp / 'daimos-k04-v1797-dying-parent/system/boot/pdp6'
cty_log = tmp / 'daimos-k04-v1797-cty.log'
dcs_log = tmp / 'daimos-k04-v1797-dcs.log'


def scan(dcs):
    dcs.sendline('PS')
    dcs.expect('PID PPID S WORDS TD RETRY PVM DETAIL ERR COMM',
               timeout=45)
    dcs.expect(r'# ', timeout=60)
    return dcs.before.replace('\r', '')


def ps_row(text, pid, parent, stage, pvm, command):
    pat = ((r'(?m)^%d\s+%d\s+\d+\s+\d+\s+%d\s+\d+\s+%d'
            r'\s+\d+\s+\d+\s+%s\s*$') %
           (pid, parent, stage, pvm, command))
    return bool(re.search(pat, text))


def run_v1797():
    print('K04 v1797 dying-parent and pinned PREVM child', flush=True)
    with cty_log.open('w', encoding='latin1') as cl, \
            dcs_log.open('w', encoding='latin1') as dl:
        sim = pexpect.spawn('nice', ['-n', '15', 'pdp6', 'boot.ini'],
                            cwd=str(root), encoding='latin1', timeout=180,
                            logfile=cl)
        dcs = None
        halted = False
        try:
            sim.expect('LOGIN: ')
            sim.sendline('ROOT')
            sim.expect('DSH V1')
            sim.expect(r'# ')
            dcs = pexpect.spawn('telnet', ['127.0.0.1', '22597'],
                                encoding='latin1', timeout=180, logfile=dl)
            dcs.expect('Connected to the PDP6 simulator DCS device')
            dcs.sendline('ROOT')
            dcs.expect('DSH V1')
            dcs.expect(r'# ')
            print('CTY/DCS ROOT logins PASS', flush=True)
            sim.sendline('TRUE')
            sim.expect('TRUE\r\n', timeout=30)
            print('CTY parent PID2 waiting for pinned TRUE PID5', flush=True)

            before = ''
            for i in range(20):
                before = scan(dcs)
                if ps_row(before, 5, 2, 3, 1, 'TRUE'):
                    break
                time.sleep(0.6)
            else:
                raise ValueError('no pre-death PID5 physical PREVM owner')
            print('Before parent TERM:\n' + before[-1000:], flush=True)

            dcs.sendline('KILL 2')
            dcs.expect('KILL 2\r\n', timeout=30)
            dcs.expect(r'# ', timeout=75)
            print('DCS foreign TERM sent to WAITing parent PID2', flush=True)

            adopted = False
            for i in range(45):
                middle = scan(dcs)
                if ps_row(middle, 5, 1, 3, 1, 'TRUE'):
                    adopted = True
                    print('INIT-adopted PREVM child while still pinned:\n'
                          + middle[-1050:], flush=True)
                    break
                time.sleep(0.8)
            if not adopted:
                raise ValueError('no live adopted child held in PREVM')

            recovered = False
            for i in range(90):
                after = scan(dcs)
                # Killing parent PID2 leaves the *lowest* free slot 2
                # available for ordinary PS children. PID5 need not be
                # reused by this particular PS invocation; requiring
                # parent=3 for PID5 would misclassify a safely FREE slot.
                pid5_present = bool(re.search(r'(?m)^5\s+', after))
                if (not pid5_present or
                        ps_row(after, 5, 3, 0, 0, 'PS')):
                    recovered = True
                    print('Old PID5 owner FREE or safely reused:\n'
                          + after[-1000:], flush=True)
                    break
                time.sleep(2)
            if not recovered:
                raise ValueError('PIN release did not retire old PID5 owner')
            dcs.sendline('HALT')
            sim.expect('HALT instruction', timeout=120)
            halted = True
            sim.expect(pexpect.EOF, timeout=30)
            print('Guest DCS operator HALT PASS', flush=True)
        except Exception:
            if dcs is not None and dcs.isalive() and not halted:
                try:
                    dcs.sendline('HALT')
                    sim.expect('HALT instruction', timeout=60)
                    halted = True
                    sim.expect(pexpect.EOF, timeout=30)
                except Exception:
                    print('Could not confirm guest HALT; discard media',
                          file=sys.stderr, flush=True)
            raise
        finally:
            if dcs is not None:
                dcs.close(force=True)
            sim.close(force=True)
    if not halted:
        raise ValueError('guest did not HALT normally')


def verify_v1797():
    mp = (root / 'kcore.map').read_text()
    syms = {name: int(addr, 8) for name, addr in re.findall(
        r'(?m)^([A-Za-z_][A-Za-z_0-9]*)\s+([0-7]+)\s*$', mp)}
    simh = (root / 'boot.simh.log').read_text(encoding='latin1')
    pos = simh.rfind('HALT instruction, PC:')
    if pos < 0 or 'Goodbye' not in simh[pos:]:
        raise ValueError('missing guest HALT and post-HALT witnesses')
    vals = {int(a, 8): int(b, 8) for a, b in re.findall(
        r'(?m)^([0-7]+):[ \t]*([0-7]{12})', simh[pos:])}

    def w(label):
        return vals[syms['k04_prevm_' + label + '_v1797']]

    base, calls, done = (w(x) for x in ('base', 'calls', 'done'))
    print('PREVM physical witnesses: base=%06o calls=%o done=%012o' %
          (base, calls, done), flush=True)
    if (base, calls, done) != (0, 0o14, 0o777777777777):
        raise ValueError('child physical MM release incorrect')
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', str(root / 'disk')],
                          capture_output=True, text=True)
    print(fsck.stdout + fsck.stderr, flush=True)
    if fsck.returncode or 'state=CLEAN' not in fsck.stdout + fsck.stderr:
        raise ValueError('D6FS not CLEAN')
    print('K04 v1797 physical dying-parent/PREVM-child PASS', flush=True)


if __name__ == '__main__':
    try:
        run_v1797()
        verify_v1797()
    except Exception as exc:
        print('K04 v1797 NOT ACCEPTED:', exc, file=sys.stderr)
        sys.exit(1)
