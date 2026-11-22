#!/usr/bin/env python3
"""Exercise physical PREVM-A and SIDL-B in a disposable PDP-6 guest.

The guest must contain the scratch v1794 assembly and a clean D6FS.
Never interrupt the running simulator; use guest HALT for shutdown.
"""
from pathlib import Path
import os
import pexpect
import re
import subprocess
import sys
import time

tmp = Path(os.environ.get('TMPDIR', str(Path.home() / 'tmp')))
root = tmp / 'daimos-k04-v1794-prevm-sidl/system/boot/pdp6'
cty_log = tmp / 'daimos-k04-v1794-cty.log'
dcs_log = tmp / 'daimos-k04-v1794-dcs.log'


def check_ps(text, pid, parent, state, stage, pvm, command):
    """Verify a real PS entry with its teardown diagnostics."""
    zero = stage == 0
    retry = '0' if zero else r'\d+'
    detail = '0' if zero else r'\d+'
    error = '0' if zero else r'\d+'
    pattern = (r'(?m)^%d\s+%d\s+%d\s+\d+\s+%d\s+%s\s+%d\s+'
               r'%s\s+%s\s+%s\s*$') % (
                   pid, parent, state, stage, retry, pvm,
                   detail, error, command)
    return bool(re.search(pattern, text.replace('\r', '')))


def run_guest():
    print('K04 v1794 PREVM-A / SIDL-B physical experiment', flush=True)
    with cty_log.open('w', encoding='latin1') as cty_stream, \
            dcs_log.open('w', encoding='latin1') as dcs_stream:
        sim = pexpect.spawn('nice', ['-n', '15', 'pdp6', 'boot.ini'],
                            cwd=str(root), encoding='latin1', timeout=180,
                            logfile=cty_stream)
        dcs = None
        halted = False
        try:
            sim.expect('LOGIN: ')
            sim.sendline('ROOT')
            sim.expect('DSH V1')
            sim.expect(r'# ')
            print('CTY ROOT login PASS', flush=True)
            dcs = pexpect.spawn('telnet', ['127.0.0.1', '22594'],
                                encoding='latin1', timeout=180,
                                logfile=dcs_stream)
            dcs.expect('Connected to the PDP6 simulator DCS device')
            dcs.sendline('ROOT')
            dcs.expect('DSH V1')
            dcs.expect(r'# ')
            print('DCS ROOT login PASS', flush=True)

            sim.sendline('TRUE')
            sim.expect('TRUE\r\n', timeout=30)
            print('A: PREVM EXIT entered; allowing retry to saturate',
                  flush=True)
            time.sleep(30)
            dcs.sendline('TRUE')
            dcs.expect('TRUE\r\n', timeout=35)
            dcs.expect(r'# ', timeout=180)
            print('B: SIDL rollback returned to DCS shell', flush=True)

            # The failed SIDL RUN returns immediately, before deferred
            # physical VM retries are complete.  Poll the real process
            # table instead of assuming that the returned shell means B
            # is already reusable.  PS may itself use PID7 temporarily.
            a_pending = False
            b_reused = False
            for sample in range(45):
                dcs.sendline('PS')
                dcs.expect('PID PPID S WORDS TD RETRY PVM DETAIL ERR COMM')
                dcs.expect(r'# ')
                middle = dcs.before.replace('\r', '')
                a_pending = check_ps(middle, 5, 2, 2, 3, 1, 'TRUE')
                b_reused = check_ps(middle, 6, 3, 2, 0, 0, 'PS')
                if a_pending and b_reused:
                    break
                time.sleep(2)
            print('Intermediate PS after B release:\n' +
                  middle[-1000:], flush=True)
            print('A pending PREVM=%s; B reusable=%s' %
                  (a_pending, b_reused), flush=True)

            sim.expect(r'# ', timeout=300)
            print('A: CTY TRUE returned after release', flush=True)
            sim.sendline('PS')
            sim.expect('PID PPID S WORDS TD RETRY PVM DETAIL ERR COMM')
            sim.expect(r'# ')
            final = sim.before.replace('\r', '')
            print('Final PS:\n' + final[-1000:], flush=True)
            a_reused = check_ps(final, 5, 2, 2, 0, 0, 'PS')
            sim.sendline('HALT')
            sim.expect('HALT instruction', timeout=120)
            halted = True
            sim.expect(pexpect.EOF, timeout=30)
            print('Guest HALT PASS', flush=True)
        finally:
            if dcs is not None:
                dcs.close(force=True)
            sim.close(force=True)

    if not halted:
        raise ValueError('guest did not HALT normally')
    return a_pending, b_reused, a_reused


def verify_physical(a_pending, b_reused, a_reused):
    map_text = (root / 'kcore.map').read_text()
    symbols = {name: int(addr, 8) for name, addr in re.findall(
        r'(?m)^([A-Za-z_][A-Za-z_0-9]*)\s+([0-7]+)\s*$', map_text)}
    simh = (root / 'boot.simh.log').read_text(encoding='latin1')
    pos = simh.rfind('HALT instruction, PC:')
    if pos < 0 or 'Goodbye' not in simh[pos:]:
        raise ValueError('no completed post-HALT transcript')
    values = {int(a, 8): int(v, 8) for a, v in re.findall(
        r'(?m)^([0-7]+):[ \t]*([0-7]{12})', simh[pos:])}

    def w(name):
        return values[symbols['k04_' + name + '_v1794']]

    for stage, attempts in (('prevm', 0o30), ('sidl', 5)):
        print('%s: base=%06o calls=%o unpin=%012o' %
              (stage, w(stage + '_base'), w(stage + '_calls'),
               w(stage + '_done')), flush=True)
        if (w(stage + '_base') != 0 or
                w(stage + '_calls') != attempts or
                w(stage + '_done') != 0o777777777777):
            raise ValueError('%s physical MM release failed' % stage)
    before, after, first, second = (w('b_' + name) for name in (
        'before', 'after', 'first', 'second'))
    print('B before=%012o after=%012o clock=%06o->%06o' %
          (before, after, first, second), flush=True)
    if ((before >> 18) & 0o777777) != 0o401000:
        raise ValueError('A not at capped 01000 before B')
    if ((after >> 18) & 0o777777) != 0o400020:
        raise ValueError('B did not rearm fresh 020')
    if ((after & 0o377777) != (first & 0o377777) or
            ((second - first) & 0o377777) != 0o20):
        raise ValueError('B first physical retry not exactly 020 ticks')
    if not (a_pending and b_reused and a_reused):
        raise ValueError('PID or teardown state did not match expected')
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', str(root / 'disk')],
                          capture_output=True, text=True)
    print(fsck.stdout + fsck.stderr, flush=True)
    if fsck.returncode or 'state=CLEAN' not in fsck.stdout + fsck.stderr:
        raise ValueError('D6FS did not shut down CLEAN')
    print('K04 v1794 physical PREVM-A / SIDL-B PASS', flush=True)


if __name__ == '__main__':
    try:
        verify_physical(*run_guest())
    except Exception as exc:
        print('K04 v1794 NOT ACCEPTED: %s' % exc, file=sys.stderr)
        sys.exit(1)
