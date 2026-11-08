#!/usr/bin/env python3
"""Exercise v1342 normal early HALT without weakening guest validation."""

import runpy
import subprocess
import sys
import tempfile
from pathlib import Path


HERE = Path(__file__).resolve().parent
SAMPLER = HERE / 'daimos-simh-swap-live-sampler-v1344.py'
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
        # Guest bytes emitted in the Ctrl-E race must survive intact.
        print('@%&', flush=True)
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
        numeric = int(address, 8)
        values = {
            0o16000: 0o17000, 0o16001: 4, 0o16002: 1,
            0o17004: (0o20000 << 18) | 0o2000,
            0o17005: 2 << 33,
            0o17010: 3 << 33,
            0o17012: (0o20000 << 18) | 0o4000,
            0o17013: 2 << 33,
        }
        print('sim> %s:\t%012o' % (address, values.get(numeric, 0)),
              flush=True)
    elif command == 'go':
        if mode != 'command':
            sys.exit(22)
        mode = 'posthalt'
        # SIMH prints this prompt on GO return; it must never enter
        # the guest-only milestone transcript even before HALT.
        sys.stdout.write('sim> ')
        sys.stdout.flush()
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
        # The stub completes after its first GO. A diagnostic sample
        # budget larger than one must not reject a successful HALT.
        early = args.copy()
        early[early.index('--count') + 1] = '4'
        early_result = subprocess.run(early, text=True, capture_output=True,
                                      timeout=12)
        if early_result.returncode != 0 or \
                '[v1332] normal guest HALT after 1/4' not in early_result.stdout:
            raise AssertionError('early guest HALT falsely rejected: ' +
                                 early_result.stdout + early_result.stderr)
        # Host-only linked process descriptor inspection: no kernel
        # fixture and no synthetic scheduler or MM failure necessary.
        kcore_map = root / 'kcore.map'
        kcore_map.write_text('proc_table 016000\n'
                             'proc_high_slot 016001\n'
                             'proc_current_slot 016002\n')
        descriptor_args = args + ['--kcore-map', str(kcore_map)]
        described = subprocess.run(descriptor_args, text=True,
                                   capture_output=True, timeout=12)
        for marker in ('[v1332] process-table sample=1',
                       'current=01', 'slots=4',
                       'slot01=RUN/R', 'slot02=SLEEP/D',
                       'slot03=RUN/R'):
            if described.returncode != 0 or marker not in described.stdout:
                raise AssertionError('linked descriptor check failed: ' +
                                     marker + described.stdout +
                                     described.stderr)
        if '[v1342] sample=1 queries=0 last_cooldown=0' not in \
                described.stdout:
            raise AssertionError('source-linked release witness omitted: ' +
                                 described.stdout + described.stderr)
        if ('[v1344] sample=1 ac1=000000000000' not in
                described.stdout or
                'drm_active=000000000000 drm_pending=000000000000' not in
                described.stdout):
            raise AssertionError('source-linked I/O witness omitted: ' +
                                 described.stdout + described.stderr)
        # Negative control: a simulator that quits normally without
        # completing the original postflight must not appear accepted.
        broken_stub = root / 'simh-early-exit-v1344.py'
        broken_stub.write_text(STUB.replace(
            "print('Goodbye', flush=True)",
            "print('postflight aborted', flush=True)"))
        broken_stub.chmod(0o700)
        malformed = early.copy()
        malformed[malformed.index('--simh') + 1] = str(broken_stub)
        malformed[malformed.index('--log') + 1] = str(
            root / 'simh-truncated-v1342.out')
        rejected = subprocess.run(malformed, text=True,
                                  capture_output=True, timeout=12)
        if rejected.returncode == 0 or \
                'without complete postflight EXIT' not in rejected.stderr:
            raise AssertionError('truncated postflight incorrectly accepted')
        output = log.read_text()
        raw = Path(str(log) + '.raw-v1306.log').read_text()
        if output.count('@%&') != 1 or raw.count('@%&') != 1:
            raise AssertionError('Ctrl-E guest output lost or duplicated')
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
        if 'sim> HALT instruction' not in raw:
            raise AssertionError('raw GO prompt was not retained')
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
    print('v1342: actual linked process table read-only snapshot, '
          'normal early HALT, strict postflight and negative controls PASS')


if __name__ == '__main__':
    main()
