#!/usr/bin/env python3
"""Independent read-only PDP-6 late-child/physical PREVM verifier."""
from pathlib import Path
import re
import subprocess
import sys


NAMES = ('k04_prevm_base_v1800', 'k04_prevm_calls_v1800',
         'k04_prevm_done_v1800')


def verify(symbols, log):
    addresses = {}
    for name, value in re.findall(
            r'(?m)^([a-zA-Z_0-9]+)\s+([0-7]+)\s*$', symbols):
        if name in addresses:
            raise ValueError('duplicate symbol')
        addresses[name] = int(value, 8)
    if set(addresses) != set(NAMES) or len(set(addresses.values())) != 3:
        raise ValueError('incomplete physical witness map')
    halt = log.rfind('HALT instruction, PC:')
    if halt < 0 or 'Goodbye' not in log[halt:]:
        raise ValueError('missing normal guest HALT')
    guest = log[:halt].replace('\r', '')
    if '!' in guest or not re.search(r'(?m)S\s*V\s*A\s*P\s*$', guest):
        raise ValueError('late child was not adopted before parent release')
    memory = {}
    for addr, value in re.findall(
            r'(?m)^([0-7]+):[ \t]*([0-7]{12})\r?$', log[halt:]):
        address = int(addr, 8)
        if address in memory:
            raise ValueError('duplicate physical readout')
        memory[address] = int(value, 8)
    try:
        base, calls, done = (memory[addresses[name]] for name in NAMES)
    except KeyError:
        raise ValueError('missing physical readout')
    if base != 0 or calls != 0o20 or done != 0o777777777777:
        raise ValueError('MM pin/unpin mismatch: %r' % ((base, calls, done),))
    return (base, calls, done)


def self_test():
    syms = ''.join('%s %06o\n' % (name, 0o25000 + i)
                   for i, name in enumerate(NAMES))
    tail = ('HALT instruction, PC: 022600\n'
            '025000:\t000000000000\n'
            '025001:\t000000000020\n'
            '025002:\t777777777777\nGoodbye\n')
    good = 'INIT V1\nSVAP\n' + tail
    verify(syms, good)
    bad = (good.replace('SVAP', 'SVP'),
           good.replace('SVAP', 'SV!aP'),
           good.replace('Goodbye', ''),
           good.replace('HALT instruction', 'STOP'),
           good.replace('000000000020', '000000000017'),
           good.replace('777777777777', '000000000000'),
           good.replace('025000:', '025003:'))
    for i, candidate in enumerate(bad):
        try:
            verify(syms, candidate)
        except ValueError:
            continue
        raise AssertionError('negative control %d accepted' % i)
    print('v1800-A positive and %d negative controls PASS' % len(bad))


def main(args):
    if args == ['--self-test']:
        self_test()
        return 0
    if len(args) != 3:
        raise ValueError('usage: verify-v1800.py MAP SIMH DISK')
    values = verify(Path(args[0]).read_text(),
                    Path(args[1]).read_text(errors='replace'))
    print('v1800-A physical PREVM:', values)
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', args[2]],
                          capture_output=True, text=True)
    print((fsck.stdout + fsck.stderr).strip())
    if fsck.returncode or 'state=CLEAN' not in fsck.stdout + fsck.stderr:
        raise ValueError('D6FS not CLEAN')
    print('K04 v1800-A real late-child adoption PASS')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError) as error:
        print('K04 v1800-A NOT ACCEPTED:', error, file=sys.stderr)
        sys.exit(1)
