#!/usr/bin/env python3
"""Test F07 protected-slot interpretation and reject invalid snapshots.

The long-running F07 guest can schedule INIT and the gateway waiter
before the requester reaches physical OOM.  Standalone v1159 retains
its stricter sleeping-only requirement for those two slots.
"""

from pathlib import Path
import subprocess
import sys
import tempfile


NAMES = ('requester', 'init', 'witness', 'waiter', 'spinner', 'holder',
         'error', 'snapshots', 'selected', 'select_calls')
VALUES = (3, 0o200024, 0o360024, 0o200024, 0o200024, 0o320024,
          0, 1, 3, 1)
VERIFIER = Path(__file__).with_name('daimos-oom-protected-verify-v1159.py')


def check(directory, values, f07, succeeds):
    addresses = directory / 'addresses'
    output = directory / 'simh.out'
    addresses.write_text(''.join('e12_%s %06o\n' % (name, 0o30000 + i)
                                 for i, name in enumerate(NAMES)))
    output.write_text(''.join('%o: %012o\n' % (0o30000 + i, value)
                              for i, value in enumerate(values)))
    result = subprocess.run((sys.executable, str(VERIFIER), str(addresses),
                             str(output), '1', str(int(f07))),
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True)
    if (result.returncode == 0) != succeeds:
        raise AssertionError('mode=%s expected=%s: %s%s' %
                             (f07, succeeds, result.stdout, result.stderr))


def main():
    with tempfile.TemporaryDirectory(prefix='daimos-f07-v1263-') as root:
        directory = Path(root)
        check(directory, VALUES, True, True)
        check(directory, VALUES, False, False)
        for name, replacement in (('witness', 0o200024),
                                  ('holder', 0o200024),
                                  ('waiter', 0),
                                  ('error', (1 << 36) - 1),
                                  ('selected', 4),
                                  ('snapshots', 0)):
            changed = list(VALUES)
            changed[NAMES.index(name)] = replacement
            check(directory, changed, True, False)
        strict = list(VALUES)
        strict[NAMES.index('init')] = 0o300024
        strict[NAMES.index('waiter')] = 0o300024
        check(directory, strict, False, True)
    print('v1263: F07 RUN/SLEEP snapshots and six failure mutants PASS')


if __name__ == '__main__':
    main()
