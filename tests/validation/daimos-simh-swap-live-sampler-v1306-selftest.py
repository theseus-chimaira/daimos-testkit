#!/usr/bin/env python3
"""Exercise the v1306 PTY pause, examine, resume and post-HALT protocol."""

import runpy
import subprocess
import sys
import tempfile
from pathlib import Path


HERE = Path(__file__).resolve().parent
SAMPLER = HERE / 'daimos-simh-swap-live-sampler-v1306.py'
FIELDS = runpy.run_path(str(SAMPLER))['FIELDS']


STUB = r'''#!/usr/bin/env python3
import os
import sys
import termios
import tty
import time
from pathlib import Path

boot = Path(sys.argv[1]).read_text()
if 'go 020\n' not in boot or '\nexit' in boot:
    sys.exit(19)
tty.setraw(0)
print('SIMH test PDP6 booted', flush=True)
mode = 'running'
line = bytearray()
while True:
    c = os.read(0, 1)
    if not c:
        sys.exit(20)
    if c == b'\x05':
        if mode != 'running':
            sys.exit(21)
        print('Simulation stopped, PC: 033652', flush=True)
        mode = 'command'
        continue
    if c not in (b'\n', b'\r'):
        line.extend(c)
        continue
    command = line.decode('ascii').strip()
    line.clear()
    if not command:
        continue
    if command == 'ex PC':
        print('sim> PC:\t033652', flush=True)
    elif command.startswith('ex ') or command.startswith('examine '):
        address = command.split(' ', 1)[1].lstrip('0') or '0'
        print('sim> %s:\t000000000000' % address, flush=True)
    elif command == 'go':
        if mode != 'command':
            sys.exit(22)
        mode = 'posthalt'
        time.sleep(0.08)
        print('HALT instruction, PC: 000020', flush=True)
    elif command == 'exit':
        if mode != 'posthalt':
            sys.exit(23)
        print('Goodbye', flush=True)
        sys.exit(0)
    else:
        sys.exit(24)
'''


def main():
    with tempfile.TemporaryDirectory(prefix='daimos-simh-v1306-test-') as td:
        root = Path(td)
        simh = root / 'simh-stub-v1306.py'
        simh.write_text(STUB)
        simh.chmod(0o700)
        addresses = root / 'addresses'
        addresses.write_text(''.join(
            '%s %06o\n' % (name, 0o20000 + index)
            for index, name in enumerate(FIELDS)))
        ini = root / 'boot.ini'
        ini.write_text('set cpu 256K\ngo 020\nexamine 020000\nexit\n')
        log = root / 'simh.out'
        args = [sys.executable, str(SAMPLER), '--simh', str(simh),
                '--ini', str(ini), '--addresses', str(addresses),
                '--log', str(log), '--interval', '1', '--count', '1',
                '--timeout', '8']
        result = subprocess.run(args, text=True, capture_output=True,
                                timeout=12)
        if result.returncode != 0:
            raise AssertionError('PTY sample failed: ' +
                                 result.stdout + result.stderr)
        output = log.read_text()
        raw = Path(str(log) + '.raw-v1306.log').read_text()
        for marker in ('HALT instruction, PC:', 'Goodbye'):
            if marker not in output:
                raise AssertionError('missing guest event: ' + marker)
        for marker in ('[v1306] sample=1', 'PC=033652',
                       'sim> 20000:', 'Goodbye'):
            if marker not in raw:
                raise AssertionError('missing raw debug event: ' + marker)
        if '[v1306] sample=' in output or 'sim> PC:' in output:
            raise AssertionError('debugger output polluted F07 guest text')
        if 'sim> ' in output or '20000:\t' not in output:
            raise AssertionError('SIMH PTY prompts polluted guest postflight')
        if ini.read_text() != 'set cpu 256K\ngo 020\nexamine 020000\nexit\n':
            raise AssertionError('original boot command file modified')
        if list(root.glob('boot-v1306-*.ini')):
            raise AssertionError('transient boot command file not cleaned')
        classifier = HERE / 'daimos-swap-no-partner-physical-v1303.py'
        classified = subprocess.run(
            [sys.executable, str(classifier), '--snapshot',
             str(addresses), str(log) + '.raw-v1306.log'],
            text=True, capture_output=True,
            timeout=5)
        if classified.returncode != 3 or \
                'NOT full-guest liveness acceptance' not in classified.stdout:
            raise AssertionError('short snapshot claimed full acceptance')
        # Negative control: a missing linked address must fail closed
        # before launching the simulator.
        addresses.write_text('f07s_diag_pressure 020000\n')
        reject = subprocess.run(args, text=True, capture_output=True,
                                timeout=5)
        if reject.returncode == 0 or 'missing required linked counters' \
                not in reject.stderr:
            raise AssertionError('missing-counter negative control escaped')
    print('v1306: PTY interrupt/read-only-examine/GO, post-HALT '
          'postflight, partial-snapshot classification, unchanged '
          'boot file and negative control PASS')


if __name__ == '__main__':
    main()
