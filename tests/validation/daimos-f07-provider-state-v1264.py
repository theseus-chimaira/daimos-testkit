#!/usr/bin/env python3
"""Assemble strict/F07 provider probes and reject missing state guards."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
DAIMOS = Path(os.environ['DAIMOS_REPO'])
DAS = Path(os.environ['PDP10_PREFIX']) / 'bin/das'
PROBE = HERE / 'daimos-oom-provider-held-v1150.py'


def generate(root, f07):
    source = DAIMOS / 'system/kernel'
    for name in ('proc/syscall_dispatch_pdp6.s', 'proc/proc_pdp6.s',
                 'fs/fs_mres.s'):
        dst = root / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes((source / name).read_bytes())
    env = dict(os.environ, V1207_TEST_SWAPSLOTS=str(int(f07)))
    subprocess.run((sys.executable, str(PROBE), str(root), '1'),
                   check=True, env=env)
    dispatcher = root / 'proc/syscall_dispatch_pdp6.s'
    subprocess.run((str(DAS), '-F', '-C', '-O',
                    str(root / 'dispatcher.dobj'), str(dispatcher)),
                   check=True, stdout=subprocess.DEVNULL)
    text = dispatcher.read_text()
    return text.split('daimos_test_brk_waiter_v1150:\n', 1)[1].split(
        'daimos_test_brk_done_v1150:', 1)[0]


def validate_f07(text):
    required = (
        'caie    7,0200000            ; RUN',
        'jrst    daimos_test_gateway_sleep_v1264',
        'jrst    daimos_test_gateway_done_v1264',
        'daimos_test_gateway_sleep_v1264:',
        'caie    7,0300000            ; SLEEP',
        'caie    7,fs_provider_wait_event_v917',
        'daimos_test_gateway_done_v1264:',
        'caie    7,daimos_test_hold_event_v1150',
    )
    if not all(line in text for line in required):
        raise AssertionError('F07 provider gate lost a required guard')
    if text.count('setom   daimos_test_error_v1150') != 3:
        raise AssertionError('invalid F07 provider error branches')


def main():
    with tempfile.TemporaryDirectory(prefix='daimos-f07-v1264-') as tmp:
        root = Path(tmp)
        strict = generate(root / 'strict', False)
        f07 = generate(root / 'f07', True)
        validate_f07(f07)
        if 'daimos_test_gateway_sleep_v1264:' in strict:
            raise AssertionError('strict v1150 unexpectedly relaxed')
        if 'caie    7,0300000            ; SLEEP' not in strict:
            raise AssertionError('strict v1150 lost sleep check')
        if 'caie    7,fs_provider_wait_event_v917' not in strict:
            raise AssertionError('strict v1150 lost event check')
        for line in ('caie    7,0200000            ; RUN',
                     'jrst    daimos_test_gateway_done_v1264',
                     'caie    7,0300000            ; SLEEP',
                     'caie    7,fs_provider_wait_event_v917',
                     'caie    7,daimos_test_hold_event_v1150',
                     'setom   daimos_test_error_v1150'):
            altered = f07.replace(line, '; removed guard', 1)
            try:
                validate_f07(altered)
            except AssertionError:
                continue
            raise AssertionError('mutation not detected: ' + line)
    print('v1264: native F07 and strict provider probes; six mutants PASS')


if __name__ == '__main__':
    main()
