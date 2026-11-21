#!/usr/bin/env python3
"""Read-only validation of the physical PDP-6 K04 SIDL/PREVM v1793 run.

Usage:
    python3 daimos-k04-sidl-prevm-verify-v1793.py --self-test
    python3 daimos-k04-sidl-prevm-verify-v1793.py MAP CTY_LOG SIMH_LOG DISK

MAP and SIMH_LOG must belong to the same corrected disposable image.
The SIMH memory examination must follow a normal guest HALT.
"""

import re
import subprocess
import sys
from pathlib import Path


FULL_V1793 = 0o777777777777
NAMES_V1793 = tuple(
    'k04_%s_v1788' % name for name in (
        'sidl_base', 'sidl_calls', 'sidl_done',
        'prevm_base', 'prevm_calls', 'prevm_done',
        'b_before', 'b_after', 'b_first', 'b_second'))


def decode_v1793(map_text, cty_text, simh_text):
    """Require both owner stages, exact MM evidence and guest PID reuse."""
    symbols = {}
    for name, addr in re.findall(
            r'(?m)^([A-Za-z_][A-Za-z_0-9]*)\s+([0-7]+)\s*$', map_text):
        if name in NAMES_V1793:
            if name in symbols:
                raise ValueError('duplicate fixture symbol')
            symbols[name] = int(addr, 8)
    if set(symbols) != set(NAMES_V1793):
        raise ValueError('incomplete corrected v1793 symbol map')

    if cty_text.count('# TRUE') < 2:
        raise ValueError('missing two distinct TRUE invocations')
    if 'UUO 000000000006' in cty_text:
        raise ValueError('uncorrected fixture UUO trap')
    header = 'PID PPID S WORDS TD RETRY PVM DETAIL ERR COMM'
    if cty_text.count(header) != 2:
        raise ValueError('missing intermediate/final PS observations')
    middle, final = cty_text.split(header)[1:]
    middle = middle.split('# ', 1)[0]
    final = final.split('# ', 1)[0]
    if not re.search(r'(?m)^5\s+2\s+1\s+\d+\s+3\s+\d+\s+0\s+'
                     r'\d+\s+0\s+TRUE\s*$', middle):
        raise ValueError('A was not still unpublished SIDL while B freed')
    if not re.search(r'(?m)^6\s+2\s+2\s+\d+\s+0\s+0\s+0\s+'
                     r'0\s+0\s+PS\s*$', middle):
        raise ValueError('B was not safely reusable during A refusal')
    if not re.search(r'(?m)^5\s+2\s+2\s+\d+\s+0\s+0\s+0\s+'
                     r'0\s+0\s+PS\s*$', final):
        raise ValueError('A was not safely reusable after final recovery')

    halt = simh_text.rfind('HALT instruction, PC:')
    if halt < 0 or 'Goodbye' not in simh_text[halt:]:
        raise ValueError('no normal guest HALT / SIMH exit')
    if 'UUO 000000000006' in simh_text[:halt]:
        raise ValueError('guest trapped before HALT')
    values = {}
    for addr, word in re.findall(
            r'(?m)^([0-7]+):[ \t]*([0-7]{12})\r?$', simh_text[halt:]):
        address = int(addr, 8)
        if address in values:
            raise ValueError('ambiguous post-HALT memory word')
        values[address] = int(word, 8)
    if not set(symbols.values()).issubset(values):
        raise ValueError('missing physical owner witnesses')

    def w(name):
        return values[symbols['k04_' + name + '_v1788']]

    if (w('sidl_base') != 0 or w('sidl_calls') != 0o14 or
            w('sidl_done') != FULL_V1793):
        raise ValueError('A exact SIDL VM owner was not released')
    if (w('prevm_base') != 0 or w('prevm_calls') != 5 or
            w('prevm_done') != FULL_V1793):
        raise ValueError('B exact PREVM VM owner was not released')
    before = w('b_before')
    after = w('b_after')
    first = w('b_first')
    second = w('b_second')
    if ((before >> 18) & 0o777777) != 0o401000:
        raise ValueError('A did not reach capped 01000 delay before B')
    if ((after >> 18) & 0o777777) != 0o400020:
        raise ValueError('B did not arm independent initial 020 delay')
    if (after & 0o377777) != (first & 0o377777):
        raise ValueError('B pending epoch does not match first refusal')
    if ((second - first) & 0o377777) != 0o20:
        raise ValueError('B physical retry was not exactly 020 ticks')
    return {'a_attempts': w('sidl_calls'),
            'b_attempts': w('prevm_calls'),
            'first': first, 'second': second,
            'before': before, 'after': after}


def self_test_v1793():
    addresses = {name: 0o25126 + i for i, name in enumerate(NAMES_V1793)}
    words = {address: 0 for address in addresses.values()}
    def set_word(name, value):
        words[addresses['k04_' + name + '_v1788']] = value
    for prefix, calls in (('sidl', 0o14), ('prevm', 5)):
        set_word(prefix + '_calls', calls)
        set_word(prefix + '_done', FULL_V1793)
    set_word('b_before', 0o401000003446)
    set_word('b_after', 0o400020004140)
    set_word('b_first', 0o4140)
    set_word('b_second', 0o4160)
    map_text = ''.join('%s %06o\n' % (name, addr)
                       for name, addr in addresses.items())
    cty = ('# TRUE\n# TRUE\n# PS\n'
           'PID PPID S WORDS TD RETRY PVM DETAIL ERR COMM\n'
           '5 2 1 2048 3 256 0 1027 0 TRUE\n'
           '6 2 2 3072 0 0 0 0 0 PS\n# PS\n'
           'PID PPID S WORDS TD RETRY PVM DETAIL ERR COMM\n'
           '5 2 2 3072 0 0 0 0 0 PS\n# HALT\n')
    simh = ('HALT instruction, PC: 022644\n' +
            ''.join('%o:\t%012o\n' % (addr, word)
                    for addr, word in sorted(words.items())) +
            'Goodbye\n')
    decode_v1793(map_text, cty, simh)
    mutations = (
        (map_text, cty.replace('5 2 1 2048 3 256',
                               '5 2 2 2048 0 0'), simh),
        (map_text, cty.replace('6 2 2 3072 0 0 0 0 0 PS',
                               '6 2 1 3072 3 16 0 1027 0 PS'), simh),
        (map_text, cty, simh.replace('HALT instruction', 'Interrupted')),
        (map_text, cty, simh.replace('%012o' % 0o4160,
                                     '%012o' % 0o4161)),
        (map_text, cty, simh.replace('%012o' % FULL_V1793,
                                     '%012o' % 0, 1)),
        (map_text, cty, simh.replace('%012o' % 0o401000003446,
                                     '%012o' % 0o400400003446)),
    )
    for i, (m, c, s) in enumerate(mutations):
        try:
            decode_v1793(m, c, s)
        except ValueError:
            pass
        else:
            raise AssertionError('negative control %d accepted' % i)
    print('K04 v1793: positive and %d negative controls PASS' %
          len(mutations))


def main_v1793(argv):
    if argv == ['--self-test']:
        self_test_v1793()
        return 0
    if len(argv) != 4:
        print('usage: %s --self-test | MAP CTY_LOG SIMH_LOG DISK' %
              Path(sys.argv[0]).name, file=sys.stderr)
        return 2
    result = decode_v1793(Path(argv[0]).read_text(),
                          Path(argv[1]).read_text(errors='replace'),
                          Path(argv[2]).read_text(errors='replace'))
    print('K04 v1793: A %d real VM attempts, B %d; B clocks %06o -> %06o' %
          (result['a_attempts'], result['b_attempts'],
           result['first'], result['second']))
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', argv[3]],
                          capture_output=True, text=True)
    output = fsck.stdout + fsck.stderr
    print(output.strip())
    if fsck.returncode or not re.search(r'state=CLEAN', output):
        raise ValueError('read-only D6FS check was not CLEAN')
    print('K04 v1793 physical SIDL-A / PREVM-B acceptance PASS')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main_v1793(sys.argv[1:]))
    except (ValueError, OSError) as exc:
        print('K04 v1793 FAIL:', exc, file=sys.stderr)
        sys.exit(1)
