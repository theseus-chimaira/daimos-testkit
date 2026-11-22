#!/usr/bin/env python3
"""Independently verify K04 v1795 permanent real-MM refusal evidence.

Usage: verifier-v1795.py --self-test
       verifier-v1795.py MAP CTY DCS SIMH DISK

No simulator control and no writes to the guest filesystem.
"""
from pathlib import Path
import re
import subprocess
import sys


PS_HEADER = 'PID PPID S WORDS TD RETRY PVM DETAIL ERR COMM'
FIELDS = tuple('k04_%s_%s_v1795' % (prefix, suffix)
               for prefix, group in (
                   ('prevm', ('base', 'calls', 'done')),
                   ('sidl', ('base', 'calls', 'done')),
                   ('b', ('before', 'after', 'first', 'second')),
                   ('a', ('calls_at_b',)))
               for suffix in group)


def scan_held_v1795(text):
    """Check an individual, complete PS scan for independent owners."""
    pending = re.search(r'(?m)^5\s+2\s+2\s+\d+\s+3\s+\d+'
                        r'\s+1\s+\d+\s+0\s+TRUE\s*$', text)
    reused = re.search(r'(?m)^6\s+3\s+2\s+\d+\s+0\s+0'
                       r'\s+0\s+0\s+0\s+PS\s*$', text)
    return bool(pending and reused)


def decode_v1795(map_text, cty_text, dcs_text, simh_text):
    symbols = {}
    for name, octal in re.findall(
            r'(?m)^([A-Za-z_][A-Za-z_0-9]*)\s+([0-7]+)\s*$', map_text):
        if name in FIELDS or name == 'proc_timer_clock':
            if name in symbols:
                raise ValueError('ambiguous witness address')
            symbols[name] = int(octal, 8)
    if set(symbols) != set(FIELDS) | {'proc_timer_clock'}:
        raise ValueError('missing or stale K04 v1795 scratch map')
    cty_text = cty_text.replace('\r', '')
    dcs_text = dcs_text.replace('\r', '')
    if cty_text.count('# TRUE') != 1 or dcs_text.count('# TRUE') != 1:
        raise ValueError('missing physical owner creation')
    if 'UUO 000000000006' in cty_text + dcs_text:
        raise ValueError('unexpected guest UUO trap')
    scans = [part.split('# ', 1)[0]
             for part in dcs_text.split(PS_HEADER)[1:]]
    if sum(scan_held_v1795(scan) for scan in scans) < 2:
        raise ValueError('no two surviving-owner PS scans before HALT')
    if 'HALT' not in dcs_text:
        raise ValueError('operator did not request HALT from DCS')
    halt = simh_text.rfind('HALT instruction, PC:')
    if halt < 0 or 'Goodbye' not in simh_text[halt:]:
        raise ValueError('no normal SIMH post-HALT witness')
    if 'UUO 000000000006' in simh_text[:halt]:
        raise ValueError('guest trap before operator shutdown')
    values = {}
    for addr, word in re.findall(
            r'(?m)^([0-7]+):[ \t]*([0-7]{12})\r?$', simh_text[halt:]):
        a = int(addr, 8)
        if a in values:
            raise ValueError('duplicate post-HALT memory witness')
        values[a] = int(word, 8)
    # The exported clock is used only to locate the adjacent, private
    # shared retry word (+2). Its own raw clock value need not be among
    # the requested post-HALT memory witnesses.
    required = {symbols[name] for name in FIELDS}
    if not required.issubset(values):
        raise ValueError('missing physical owner words')

    def w(label):
        return values[symbols['k04_' + label + '_v1795']]

    base = w('prevm_base')
    calls = w('prevm_calls')
    first_calls = w('a_calls_at_b')
    if (base == 0 or w('prevm_done') != 0 or
            first_calls < 6 or calls < first_calls + 3 or
            calls >= first_calls + 40):
        raise ValueError('A was released, stalled or busy-looping')
    if (w('sidl_base') != 0 or w('sidl_calls') != 5 or
            w('sidl_done') != 0o777777777777):
        raise ValueError('B SIDL MM owner was not independently released')
    before = w('b_before')
    after = w('b_after')
    first = w('b_first')
    second = w('b_second')
    if ((before >> 18) & 0o777777) != 0o401000:
        raise ValueError('A not capped when B first pinned')
    if ((after >> 18) & 0o777777) != 0o400020:
        raise ValueError('B did not rearm fresh 020 interval')
    if ((after & 0o377777) != (first & 0o377777) or
            ((second - first) & 0o377777) != 0o20):
        raise ValueError('B first real retry not exactly 020 ticks')
    shared_addr = symbols['proc_timer_clock'] + 2
    if shared_addr not in values:
        raise ValueError('missing final shared pending/backoff witness')
    shared = values[shared_addr]
    if ((shared >> 18) & 0o777777) != 0o401000:
        raise ValueError('permanently refused A lost capped pending state')
    return {'a_base': base, 'a_calls': calls,
            'a_at_b': first_calls, 'shared': shared,
            'before': before, 'after': after,
            'first': first, 'second': second}


def self_test_v1795():
    sym = {label: 0o25121 + i for i, label in enumerate(FIELDS)}
    sym['proc_timer_clock'] = 0o25115
    vals = {addr: 0 for addr in sym.values()}
    vals[0o25117] = 0o401000026034
    def put(label, word):
        vals[sym['k04_' + label + '_v1795']] = word
    put('prevm_base', 0o760000)
    put('prevm_calls', 0o21)
    put('prevm_done', 0)
    put('sidl_calls', 5)
    put('sidl_done', 0o777777777777)
    put('a_calls_at_b', 6)
    put('b_before', 0o401000004625)
    put('b_after', 0o400020005265)
    put('b_first', 0o5265)
    put('b_second', 0o5305)
    map_text = ''.join('%s %06o\n' % (name, addr)
                       for name, addr in sym.items())
    cty = '# TRUE\n'
    scan = (PS_HEADER + '\n5 2 2 2048 3 512 1 0 0 TRUE\n'
            '6 3 2 3072 0 0 0 0 0 PS\n# ')
    dcs = '# TRUE\n' + scan + '\n' + scan + '\nHALT\n'
    simh = ('HALT instruction, PC: 022620\n' +
            ''.join('%o:\t%012o\n' % (addr, word)
                    for addr, word in sorted(vals.items())) + 'Goodbye\n')
    decode_v1795(map_text, cty, dcs, simh)
    bad = (
        (map_text, cty, dcs.replace('5 2 2 2048 3 512 1',
                                    '5 2 2 2048 3 512 0'), simh),
        (map_text, cty, dcs.replace('HALT', 'EXIT'), simh),
        (map_text, cty, dcs, simh.replace('HALT instruction', 'Stop')),
        (map_text, cty, dcs, simh.replace('%012o' % 0o760000,
                                          '%012o' % 0)),
        (map_text, cty, dcs, simh.replace('%012o' % 0o21,
                                          '%012o' % 7)),
        (map_text, cty, dcs, simh.replace('%012o' % 0o5305,
                                          '%012o' % 0o5306)),
        (map_text, cty, dcs, simh.replace('%012o' % 0o401000026034,
                                          '%012o' % 0o400020026034)),
    )
    for i, args in enumerate(bad):
        try:
            decode_v1795(*args)
        except ValueError:
            continue
        raise AssertionError('negative control %d unexpectedly passed' % i)
    print('K04 v1795 positive + %d negative controls PASS' % len(bad))


def main_v1795(argv):
    if argv == ['--self-test']:
        self_test_v1795()
        return 0
    if len(argv) != 5:
        print('usage: verifier-v1795.py --self-test | MAP CTY DCS SIMH DISK',
              file=sys.stderr)
        return 2
    result = decode_v1795(*(Path(p).read_text(errors='replace')
                            for p in argv[:4]))
    print('A pinned base=%06o calls=%o since B=%o shared=%012o' %
          (result['a_base'], result['a_calls'],
           result['a_at_b'], result['shared']))
    print('B before=%012o after=%012o retry %06o -> %06o' %
          (result['before'], result['after'],
           result['first'], result['second']))
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', argv[4]],
                          capture_output=True, text=True)
    out = fsck.stdout + fsck.stderr
    print(out.strip())
    if fsck.returncode or 'state=CLEAN' not in out:
        raise ValueError('D6FS not CLEAN after orderly operator HALT')
    print('K04 v1795 permanent physical MM refusal verified PASS')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main_v1795(sys.argv[1:]))
    except (ValueError, OSError) as exc:
        print('K04 v1795 NOT ACCEPTED:', exc, file=sys.stderr)
        sys.exit(1)
