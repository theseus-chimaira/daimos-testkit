#!/usr/bin/env python3
"""Read-only real MM pinned DISCARD versus session HUP verifier.

Usage: verify-v1799.py --self-test | SYMBOLS SIMH_LOG DISK_DIR
"""
from pathlib import Path
import re
import subprocess
import sys


FIELDS = ('run_injected', 'uarea_base', 'uarea_calls', 'uarea_done',
          'discard_deliver', 'discard_seen', 'discard_fails',
          'discard_success', 'discard_bad')
NAMES = tuple('k04_' + x + '_v1799' for x in FIELDS)


def decode(symbols, simh):
    syms = {}
    for name, address in re.findall(
            r'(?m)^([A-Za-z_][A-Za-z_0-9]*)\s+([0-7]+)\s*$', symbols):
        if name in syms:
            raise ValueError('duplicate witness name')
        syms[name] = int(address, 8)
    if set(syms) != set(NAMES) or len(set(syms.values())) != len(NAMES):
        raise ValueError('incomplete/aliased physical symbol map')
    pos = simh.rfind('HALT instruction, PC:')
    if pos < 0 or 'Goodbye' not in simh[pos:]:
        raise ValueError('no complete guest HALT')
    guest = simh[:pos].replace('\r', '')
    if '!' in guest or not re.search(r'(?m)S\s*H\s*P\s*$', guest):
        raise ValueError('no successful guest S/H/P or guest diagnostic')
    words = {}
    for address, value in re.findall(
            r'(?m)^([0-7]+):[ \t]*([0-7]{12})\r?$', simh[pos:]):
        addr = int(address, 8)
        if addr in words:
            raise ValueError('duplicate physical memory readout')
        words[addr] = int(value, 8)
    try:
        result = dict((field, words[syms[name]])
                      for field, name in zip(FIELDS, NAMES))
    except KeyError:
        raise ValueError('missing post-HALT MM or HUP witness')
    if (result['run_injected'] != 0o777777777777 or
            result['uarea_base'] != 0 or
            result['uarea_calls'] != 0o14 or
            result['uarea_done'] != 0o777777777777):
        raise ValueError('real RUN rollback/MM release failed: %r' % result)
    if (result['discard_deliver'] < 1 or
            result['discard_seen'] < 1 or
            result['discard_fails'] < 1 or
            result['discard_success'] != 1 or
            result['discard_bad'] != 0):
        raise ValueError('DISCARD HUP/TTY ordering failed: %r' % result)
    if result['discard_deliver'] != result['discard_seen']:
        raise ValueError('not all attempted HUPs saw real DISCARD')
    return result


def self_test():
    syms = dict((name, 0o25100 + i) for i, name in enumerate(NAMES))
    names = ''.join('%s %06o\n' % (name, addr)
                    for name, addr in syms.items())
    values = (0o777777777777, 0, 0o14, 0o777777777777,
              5, 5, 5, 1, 0)
    simh = ('INIT V1\nSHP\nHALT instruction, PC: 022650\n' +
            ''.join('%06o:\t%012o\n' % (syms[name], word)
                    for name, word in zip(NAMES, values)) + 'Goodbye\n')
    decode(names, simh)
    bad = (
        (names, simh.replace('SHP', 'SP')),
        (names, simh.replace('SHP', 'HSP')),
        (names, simh.replace('Goodbye', '')),
        (names, simh.replace('HALT instruction', 'STOP')),
        (names, simh.replace('INIT V1', 'INIT V1\n!a')),
        (names, simh.replace('%012o' % 0o14, '%012o' % 0o13)),
        (names, simh.replace('%06o:\t%012o' %
                             (syms[NAMES[5]], 5),
                             '%06o:\t%012o' % (syms[NAMES[5]], 4))),
        (names.replace(NAMES[0], 'other_name'), simh),
    )
    for i, args in enumerate(bad):
        try:
            decode(*args)
        except ValueError:
            continue
        raise AssertionError('negative control %d accepted' % i)
    print('v1799 positive + %d negative controls PASS' % len(bad))


def main(argv):
    if argv == ['--self-test']:
        self_test()
        return 0
    if len(argv) != 3:
        print('usage: verify-v1799.py --self-test | MAP SIMH DISK',
              file=sys.stderr)
        return 2
    result = decode(Path(argv[0]).read_text(),
                    Path(argv[1]).read_text(errors='replace'))
    print('K04 v1799 physical DISCARD/HUP witnesses:', result)
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', argv[2]],
                          capture_output=True, text=True)
    out = fsck.stdout + fsck.stderr
    print(out.strip())
    if fsck.returncode or 'state=CLEAN' not in out:
        raise ValueError('D6FS not CLEAN')
    print('K04 v1799 real VM_NONE DISCARD/HUP PASS')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError) as exc:
        print('K04 v1799 NOT ACCEPTED:', exc, file=sys.stderr)
        sys.exit(1)
