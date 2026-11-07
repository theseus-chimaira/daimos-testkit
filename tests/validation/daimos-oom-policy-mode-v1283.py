#!/usr/bin/env python3
"""Test the disposable OOM source switch in both release phases.

These checks never enable the checked-out production kernel. A phase
expectation must match the exact one-word assembly policy declaration.
"""

import os
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).parent
RUNNERS = (
    'daimos-oom-requester-live-v1075.sh',
    'daimos-oom-requester-provider-mm-v1077.sh',
    'daimos-oom-requester-live-v1075-2000s-r1.sh',
)
GATE = '.equ    PROC_OOM_BRK_ENABLED_V1000,'


def script_body(name):
    text = (ROOT / name).read_text()
    marker = 'proc/syscall_dispatch_pdp6.s" "$enable" <<\'PY\'\n'
    assert text.count(marker) == 1, name
    return text.split(marker, 1)[1].split('\nPY\n', 1)[0] + '\n'


def check(body, fixture, actual, desired, expected, good):
    fixture.write_text(actual)
    env = os.environ.copy()
    env['V1283_PRODUCTION_OOM_DEFAULT'] = expected
    result = subprocess.run([sys.executable, '-', str(fixture), desired],
                            input=body, env=env, text=True,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    if good:
        assert result.returncode == 0, result.stderr
        assert fixture.read_text() == GATE + desired + '\n', \
            'disposable policy does not match requested guest'
    else:
        assert result.returncode != 0, 'unsafe policy was accepted'
        assert fixture.read_text() == actual, \
            'unsafe policy modified the fixture before rejection'


def main():
    temp_root = os.environ.get('TMPDIR', str(Path.home() / 'tmp'))
    with tempfile.TemporaryDirectory(prefix='daimos-oom-v1283-',
                                     dir=temp_root) as name:
        fixture = Path(name) / 'syscall_dispatch_pdp6.s'
        for runner in RUNNERS:
            body = script_body(runner)
            for expected in ('0', '1'):
                actual = GATE + expected + '\n'
                for desired in ('0', '1'):
                    check(body, fixture, actual, desired, expected, True)
                check(body, fixture, actual, '1',
                      '1' if expected == '0' else '0', False)
                check(body, fixture, GATE + '0\n' + GATE + '1\n',
                      '1', expected, False)
    print('v1283: three disposable OOM runners, both production phases, '
          'both requested modes and twelve unsafe phase/duplicate '
          'mutations rejected PASS')


if __name__ == '__main__':
    main()
