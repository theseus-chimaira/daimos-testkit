#!/usr/bin/env python3
"""Validate the physical PDP-6 K04 PREVM-A / SIDL-B v1794 evidence.

Usage:
    python3 daimos-k04-prevm-sidl-verify-v1794.py --self-test
    python3 daimos-k04-prevm-sidl-verify-v1794.py MAP CTY DCS SIMH DISK

This program neither modifies a guest image nor injects MM failures.
"""
import re
import subprocess
import sys
from pathlib import Path


WORD_ALL_ONES = 0o777777777777
K04_WORDS = tuple('k04_' + stage + '_' + field + '_v1794'
                  for stage, fields in (
                      ('prevm', ('base', 'calls', 'done')),
                      ('sidl', ('base', 'calls', 'done')),
                      ('b', ('before', 'after', 'first', 'second')))
                  for field in fields)
PS_HEADER = 'PID PPID S WORDS TD RETRY PVM DETAIL ERR COMM'


def ps_entry(text, slot, parent, state, stage, pvm, command):
    """Read only exact live PS rows, not program echo or unrelated text."""
    zero = stage == 0
    retry = '0' if zero else r'\d+'
    detail = '0' if zero else r'\d+'
    error = '0' if zero else r'\d+'
    pattern = (r'(?m)^%d\s+%d\s+%d\s+\d+\s+%d\s+%s\s+%d\s+'
               r'%s\s+%s\s+%s\s*$') % (
                   slot, parent, state, stage, retry, pvm,
                   detail, error, command)
    return bool(re.search(pattern, text))


def decode_v1794(map_text, cty_text, dcs_text, simh_text):
    symbols = {}
    for name, address in re.findall(
            r'(?m)^([A-Za-z_][A-Za-z_0-9]*)\s+([0-7]+)\s*$', map_text):
        if name in K04_WORDS:
            if name in symbols:
                raise ValueError('ambiguous witness symbol')
            symbols[name] = int(address, 8)
    if set(symbols) != set(K04_WORDS) or len(set(symbols.values())) != 10:
        raise ValueError('invalid scratch-only symbol map')

    cty_text = cty_text.replace('\r', '')
    dcs_text = dcs_text.replace('\r', '')
    if 'UUO 000000000006' in cty_text + dcs_text:
        raise ValueError('guest UUO trap')
    if cty_text.count('# TRUE') != 1 or dcs_text.count('# TRUE') != 1:
        raise ValueError('wrong first A/B process invocation sequence')
    # Require A PREVM and a safely reusable B in the SAME DCS PS scan.
    middle = False
    for scan in dcs_text.split(PS_HEADER)[1:]:
        scan = scan.split('# ', 1)[0]
        if (ps_entry(scan, 5, 2, 2, 3, 1, 'TRUE') and
                ps_entry(scan, 6, 3, 2, 0, 0, 'PS')):
            middle = True
            break
    if not middle:
        raise ValueError('no simultaneous refused A and reusable B')
    # Parent shell must reclaim PID5 only after its pin is released.
    if not any(ps_entry(scan.split('# ', 1)[0], 5, 2, 2, 0, 0, 'PS')
               for scan in cty_text.split(PS_HEADER)[1:]):
        raise ValueError('A is not safely reusable after real MM release')

    halt = simh_text.rfind('HALT instruction, PC:')
    if halt < 0 or 'Goodbye' not in simh_text[halt:]:
        raise ValueError('missing normal HALT / SIMH exit')
    if 'UUO 000000000006' in simh_text[:halt]:
        raise ValueError('guest trap preceding HALT')
    values = {}
    for address, word in re.findall(
            r'(?m)^([0-7]+):[ \t]*([0-7]{12})\r?$', simh_text[halt:]):
        addr = int(address, 8)
        if addr in values:
            raise ValueError('duplicate post-HALT word')
        values[addr] = int(word, 8)
    if not set(symbols.values()).issubset(values):
        raise ValueError('missing post-HALT physical MM witness')

    def w(stage, field):
        return values[symbols['k04_%s_%s_v1794' % (stage, field)]]

    for stage, calls in (('prevm', 0o30), ('sidl', 5)):
        if (w(stage, 'base') != 0 or w(stage, 'calls') != calls or
                w(stage, 'done') != WORD_ALL_ONES):
            raise ValueError('incomplete physical %s release' % stage)
    before = w('b', 'before')
    after = w('b', 'after')
    first = w('b', 'first')
    second = w('b', 'second')
    if ((before >> 18) & 0o777777) != 0o401000:
        raise ValueError('A not at capped 01000 delay before SIDL B')
    if ((after >> 18) & 0o777777) != 0o400020:
        raise ValueError('B did not receive independent initial 020')
    if (after & 0o377777) != (first & 0o377777):
        raise ValueError('B first pending epoch does not match clock')
    if ((second - first) & 0o377777) != 0o20:
        raise ValueError('B first real retry not exactly 020 ticks')
    return (before, after, first, second)


def self_test_v1794():
    sym = {name: 0o25126 + i for i, name in enumerate(K04_WORDS)}
    words = {addr: 0 for addr in sym.values()}
    def put(stage, field, value):
        words[sym['k04_%s_%s_v1794' % (stage, field)]] = value
    for stage, calls in (('prevm', 0o30), ('sidl', 5)):
        put(stage, 'calls', calls)
        put(stage, 'done', WORD_ALL_ONES)
    put('b', 'before', 0o401000003446)
    put('b', 'after', 0o400020004140)
    put('b', 'first', 0o4140)
    put('b', 'second', 0o4160)
    m = ''.join('%s %06o\n' % (name, address)
                for name, address in sym.items())
    cty = ('# TRUE\n' + PS_HEADER + '\n'
           '5 2 2 3072 0 0 0 0 0 PS\n# HALT\n')
    dcs = ('# TRUE\n' + PS_HEADER + '\n'
           '5 2 2 2048 3 512 1 0 0 TRUE\n'
           '6 3 2 3072 0 0 0 0 0 PS\n# ')
    simh = ('HALT instruction, PC: 022620\n' +
            ''.join('%o:\t%012o\n' % (addr, word)
                    for addr, word in sorted(words.items())) + 'Goodbye\n')
    decode_v1794(m, cty, dcs, simh)
    controls = (
        (m, cty, dcs.replace('3 512 1', '3 512 0'), simh),
        (m, cty, dcs.replace('6 3 2 3072 0', '6 3 1 3072 3'), simh),
        (m, cty, dcs.replace('6 3 2 3072 0 0 0 0 0 PS',
                              '6 3 2 3072 0 4 0 0 0 PS'), simh),
        (m, cty.replace('5 2 2 3072 0', '5 2 1 3072 3'), dcs, simh),
        (m, cty, dcs, simh.replace('HALT instruction', 'Stop')),
        (m, cty, dcs, simh.replace('%012o' % 0o4160,
                                   '%012o' % 0o4161)),
        (m, cty, dcs, simh.replace('%012o' % WORD_ALL_ONES,
                                   '%012o' % 0, 1)),
        (m, cty, dcs, simh.replace('%012o' % 0o401000003446,
                                   '%012o' % 0o400400003446)),
    )
    for i, args in enumerate(controls):
        try:
            decode_v1794(*args)
        except ValueError:
            continue
        raise AssertionError('negative control %d unexpectedly PASS' % i)
    print('K04 v1794: positive + %d negative controls PASS' %
          len(controls))


def main(argv):
    if argv == ['--self-test']:
        self_test_v1794()
        return 0
    if len(argv) != 5:
        print('usage: %s --self-test | MAP CTY DCS SIMH DISK' %
              Path(sys.argv[0]).name, file=sys.stderr)
        return 2
    result = decode_v1794(*(Path(path).read_text(errors='replace')
                            for path in argv[:4]))
    print('A saturated %012o, B rearmed %012o, clocks %06o -> %06o' %
          result)
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', argv[4]],
                          capture_output=True, text=True)
    output = fsck.stdout + fsck.stderr
    print(output.strip())
    if fsck.returncode or 'state=CLEAN' not in output:
        raise ValueError('read-only D6FS not CLEAN')
    print('K04 v1794 physical PREVM-A / SIDL-B verified PASS')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError) as exc:
        print('K04 v1794 NOT ACCEPTED:', exc, file=sys.stderr)
        sys.exit(1)
