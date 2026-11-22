#!/usr/bin/env python3
"""PDP-6 physical permanent PREVM pin with orderly operator HALT.

Runs only against disposable v1795 with real MM pin instrumentation.
The CTY TRUE deliberately never returns; DCS is the operator console.
"""
from pathlib import Path
import os
import pexpect
import re
import subprocess
import sys
import time


tmp = Path(os.environ.get('TMPDIR', str(Path.home() / 'tmp')))
root = tmp / 'daimos-k04-v1795-permanent-prevm/system/boot/pdp6'
cty_log = tmp / 'daimos-k04-v1795-cty.log'
dcs_log = tmp / 'daimos-k04-v1795-dcs.log'


def ps_status(text):
    """Return whether A stays quarantined and B is fully reusable."""
    text = text.replace('\r', '')
    a = bool(re.search(r'(?m)^5\s+2\s+2\s+\d+\s+3\s+\d+'
                       r'\s+1\s+\d+\s+0\s+TRUE\s*$', text))
    b = bool(re.search(r'(?m)^6\s+3\s+2\s+\d+\s+0\s+0'
                       r'\s+0\s+0\s+0\s+PS\s*$', text))
    return a, b


def dcs_ps(dcs):
    dcs.sendline('PS')
    dcs.expect('PID PPID S WORDS TD RETRY PVM DETAIL ERR COMM',
               timeout=60)
    dcs.expect(r'# ', timeout=90)
    return dcs.before.replace('\r', '')


def run_v1795():
    print('K04 v1795: real permanently pinned A; B recovers', flush=True)
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
            print('CTY ROOT PASS', flush=True)
            dcs = pexpect.spawn('telnet', ['127.0.0.1', '22595'],
                                encoding='latin1', timeout=180, logfile=dl)
            dcs.expect('Connected to the PDP6 simulator DCS device')
            dcs.sendline('ROOT')
            dcs.expect('DSH V1')
            dcs.expect(r'# ')
            print('DCS ROOT PASS', flush=True)
            sim.sendline('TRUE')
            sim.expect('TRUE\r\n', timeout=30)
            print('A entered PREVM with permanent physical VM pin',
                  flush=True)
            time.sleep(30)
            dcs.sendline('TRUE')
            dcs.expect('TRUE\r\n', timeout=40)
            dcs.expect(r'# ', timeout=180)
            print('B SIDL rollback entered', flush=True)

            first = ''
            for sample in range(45):
                first = dcs_ps(dcs)
                if all(ps_status(first)):
                    break
                time.sleep(2)
            else:
                raise ValueError('B did not become reusable while A pinned')
            print('A still PREVM, B safely reusable:\n' + first[-1000:],
                  flush=True)

            # The shared clock is now allowed to make several capped
            # advances. A stays physically pinned without an unpin path.
            time.sleep(80)
            second = dcs_ps(dcs)
            if not all(ps_status(second)):
                raise ValueError('A was reused or B regressed during hold')
            print('DCS still scheduled with A held:\n' + second[-1000:],
                  flush=True)
            dcs.sendline('HALT')
            sim.expect('HALT instruction', timeout=120)
            halted = True
            sim.expect(pexpect.EOF, timeout=30)
            print('Orderly guest DCS operator HALT PASS', flush=True)
        finally:
            if dcs is not None:
                dcs.close(force=True)
            sim.close(force=True)
    if not halted:
        raise ValueError('no guest-initiated operator HALT')


def verify_v1795():
    mp = (root / 'kcore.map').read_text()
    syms = {name: int(addr, 8) for name, addr in re.findall(
        r'(?m)^([A-Za-z_][A-Za-z_0-9]*)\s+([0-7]+)\s*$', mp)}
    simh = (root / 'boot.simh.log').read_text(encoding='latin1')
    pos = simh.rfind('HALT instruction, PC:')
    if pos < 0 or 'Goodbye' not in simh[pos:]:
        raise ValueError('no normal operator HALT transcript')
    data = {int(a, 8): int(v, 8) for a, v in re.findall(
        r'(?m)^([0-7]+):[ \t]*([0-7]{12})', simh[pos:])}

    def w(label):
        return data[syms['k04_' + label + '_v1795']]

    abase, acalls, adone = (w('prevm_' + x)
                           for x in ('base', 'calls', 'done'))
    bbase, bcalls, bdone = (w('sidl_' + x)
                           for x in ('base', 'calls', 'done'))
    baseline = w('a_calls_at_b')
    before, after, first, second = (w('b_' + x) for x in (
        'before', 'after', 'first', 'second'))
    print('A still pinned: base=%06o attempts=%o at B=%o done=%o' %
          (abase, acalls, baseline, adone), flush=True)
    print('B released: base=%o attempts=%o done=%012o' %
          (bbase, bcalls, bdone), flush=True)
    print('B retry: before=%012o after=%012o clock=%06o->%06o' %
          (before, after, first, second), flush=True)
    if not (abase != 0 and adone == 0 and baseline >= 6 and
            acalls >= baseline + 3 and acalls < baseline + 40):
        raise ValueError('A was released or retries were unbounded/stalled')
    if (bbase != 0 or bcalls != 5 or bdone != 0o777777777777):
        raise ValueError('B independent physical SIDL release failed')
    if ((before >> 18) & 0o777777) != 0o401000:
        raise ValueError('A was not saturated before B')
    if ((after >> 18) & 0o777777) != 0o400020:
        raise ValueError('B did not reset the first interval to 020')
    if ((after & 0o377777) != (first & 0o377777) or
            ((second - first) & 0o377777) != 0o20):
        raise ValueError('B did not retry exactly 020 qualified ticks')
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', str(root / 'disk')],
                          capture_output=True, text=True)
    print(fsck.stdout + fsck.stderr, flush=True)
    if fsck.returncode or 'state=CLEAN' not in fsck.stdout + fsck.stderr:
        raise ValueError('D6FS was not CLEAN after operator HALT')
    print('K04 v1795 permanent physical MM refusal PASS', flush=True)


if __name__ == '__main__':
    try:
        run_v1795()
        verify_v1795()
    except Exception as exc:
        print('K04 v1795 NOT ACCEPTED:', exc, file=sys.stderr)
        sys.exit(1)
