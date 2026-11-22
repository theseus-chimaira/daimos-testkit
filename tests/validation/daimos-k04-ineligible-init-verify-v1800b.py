#!/usr/bin/env python3
"""Read-only v1800-B physical INIT/parent/child orphan verifier.

All witnesses are read from actual PDP-6 memory after normal HALT.
The verifier never patches source, process tables, or disk images.
"""
from pathlib import Path
import re
import subprocess
import sys


FIELDS = ('prevm_base', 'prevm_calls', 'prevm_done',
          'prevm_bad_count', 'orphan_free', 'orphan_zombie',
          'orphan_bad', 'sync_calls', 'sync_refused',
          'sync_delegated', 'sync_bad')
NAMES = tuple('k04_' + field + '_v1800b' for field in FIELDS)
MASK36 = 0o777777777777


def decode(symbols, simh):
    addresses = {}
    for name, address in re.findall(
            r'(?m)^([A-Za-z_][A-Za-z_0-9]*)\s+([0-7]+)\s*$', symbols):
        if name in addresses:
            raise ValueError('duplicate witness name')
        addresses[name] = int(address, 8)
    if set(addresses) != set(NAMES) or len(set(addresses.values())) != len(NAMES):
        raise ValueError('incomplete or overlapping witness map')

    halt = simh.rfind('HALT instruction, PC:')
    if halt < 0 or 'Goodbye' not in simh[halt:]:
        raise ValueError('missing actual normal guest HALT')
    guest = simh[:halt].replace('\r', '')
    if '!' in guest or not re.search(r'(?m)O\s*S\s*F\s*V\s*R\s*P\s*$', guest):
        raise ValueError('bad guest stage sequence or guest assertion')
    memory = {}
    for address, word in re.findall(
            r'(?m)^([0-7]+):[ \t]*([0-7]{12})\r?$', simh[halt:]):
        value = int(address, 8)
        if value in memory:
            raise ValueError('duplicate physical readout')
        memory[value] = int(word, 8)
    try:
        result = dict((field, memory[addresses[name]])
                      for field, name in zip(FIELDS, NAMES))
    except KeyError:
        raise ValueError('missing source-linked physical memory witness')

    if (result['prevm_base'] != 0 or
            result['prevm_calls'] != 0o20 or
            result['prevm_done'] != MASK36 or
            result['prevm_bad_count'] != 0):
        raise ValueError('real pinned PID3 VM owner not released: %r' % result)
    if (result['orphan_free'] != 1 or
            result['orphan_zombie'] != 0 or
            result['orphan_bad'] != 0):
        raise ValueError('PID4 not reclaimed exactly once while INIT refused: %r' % result)
    if (result['sync_refused'] < 1 or
            result['sync_delegated'] != 1 or
            result['sync_bad'] != 0 or
            result['sync_calls'] !=
            result['sync_refused'] + result['sync_delegated']):
        raise ValueError('INIT FD3 SYNC ownership/refusal mismatch: %r' % result)
    return result


def self_test():
    locations = dict((name, 0o25120 + i) for i, name in enumerate(NAMES))
    symbols = ''.join('%s %06o\n' % (name, locations[name]) for name in NAMES)
    values = (0, 0o20, MASK36, 0, 1, 0, 0, 5, 4, 1, 0)
    trailer = ('HALT instruction, PC: 022700\n' +
               ''.join('%06o:\t%012o\n' % (locations[name], value)
                       for name, value in zip(NAMES, values)) +
               'Goodbye\n')
    good = 'INIT V1\nOSFVRP\n' + trailer
    decode(symbols, good)
    mutants = (
        (symbols, good.replace('OSFVRP', 'OSFRVP')),
        (symbols, good.replace('OSFVRP', 'OSFVP')),
        (symbols, good.replace('OSFVRP', 'OSFV!xRP')),
        (symbols, good.replace('HALT instruction', 'STOP')),
        (symbols, good.replace('Goodbye', '')),
        (symbols, good.replace('%012o' % values[1], '%012o' % 0o17)),
        (symbols, good.replace('%06o:\t%012o' %
                              (locations[NAMES[4]], 1),
                              '%06o:\t%012o' % (locations[NAMES[4]], 0))),
        (symbols, good.replace('%06o:\t%012o' %
                              (locations[NAMES[5]], 0),
                              '%06o:\t%012o' % (locations[NAMES[5]], 1))),
        (symbols, good.replace('%06o:\t%012o' %
                              (locations[NAMES[6]], 0),
                              '%06o:\t%012o' % (locations[NAMES[6]], 1))),
        (symbols, good.replace('%06o:\t%012o' %
                              (locations[NAMES[9]], 1),
                              '%06o:\t%012o' % (locations[NAMES[9]], 0))),
        (symbols.replace(NAMES[0], 'wrong_name'), good),
        (symbols, good.replace('%06o:\t' % locations[NAMES[0]],
                               '025777:\t')),
    )
    for i, (labels, transcript) in enumerate(mutants):
        try:
            decode(labels, transcript)
        except ValueError:
            continue
        raise AssertionError('negative control %d was accepted' % i)
    print('v1800-B independent positive + %d negative controls PASS' %
          len(mutants))


def main(arguments):
    if arguments == ['--self-test']:
        self_test()
        return 0
    if len(arguments) != 3:
        raise ValueError('usage: verify-v1800b.py MAP SIMH_LOG DISK_DIR')
    result = decode(Path(arguments[0]).read_text(),
                    Path(arguments[1]).read_text(errors='replace'))
    print('K04 v1800-B physical INIT/parent/child witnesses:', result)
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', arguments[2]],
                          capture_output=True, text=True)
    output = fsck.stdout + fsck.stderr
    print(output.strip())
    if fsck.returncode or 'state=CLEAN' not in output:
        raise ValueError('read-only D6FS did not report CLEAN')
    print('K04 v1800-B ineligible INIT and direct orphan FREE PASS')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError) as error:
        print('K04 v1800-B NOT ACCEPTED:', error, file=sys.stderr)
        sys.exit(1)
