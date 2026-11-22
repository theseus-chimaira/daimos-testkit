#!/usr/bin/env python3
"""Read-only K04 v1796 fatal FILE/HUP physical witness verifier.

Usage: verifier.py --self-test | WITNESS_MAP SIMH_TRANSCRIPT DISK_DIR
"""
from pathlib import Path
import re
import subprocess
import sys


LABELS = ('k04_sync_calls_v1796', 'k04_sync_refused_v1796',
          'k04_sync_delegated_v1796', 'k04_sync_mismatch_v1796',
          'k04_session_calls_v1796', 'k04_session_bad_v1796')
EXPECTED = (11, 10, 1, 0, 1, 0)


def decode_v1796(symbol_text, transcript):
    symbols = {}
    for name, address in re.findall(
            r'(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$', symbol_text):
        if name in symbols:
            raise ValueError('duplicate symbol')
        symbols[name] = int(address, 8)
    if set(symbols) != set(LABELS):
        raise ValueError('wrong scratch symbols')
    if len(set(symbols.values())) != len(LABELS):
        raise ValueError('witness address alias')
    pos = transcript.rfind('HALT instruction, PC:')
    if pos < 0 or 'Goodbye' not in transcript[pos:]:
        raise ValueError('no normal guest HALT and SIMH exit')
    boot = transcript[:pos].replace('\r', '')
    if 'UUO 000000000006' in boot or '!' in boot:
        raise ValueError('guest diagnostic failure/UUO')
    if not re.search(r'S\s*F\s*P', boot):
        raise ValueError('no sleeping owner, FILE-stage, final WAIT sequence')
    memory = {}
    for addr, word in re.findall(
            r'(?m)^([0-7]+):[ \t]*([0-7]{12})\r?$',
            transcript[pos:]):
        address = int(addr, 8)
        if address in memory:
            raise ValueError('duplicate physical memory word')
        memory[address] = int(word, 8)
    try:
        values = tuple(memory[symbols[name]] for name in LABELS)
    except KeyError:
        raise ValueError('missing physical FILE/HUP witness')
    if values != EXPECTED:
        raise ValueError('FILE/HUP counters %r expected %r' %
                         (values, EXPECTED))
    return values


def self_test():
    addresses = dict((name, 0o25120 + i)
                     for i, name in enumerate(LABELS))
    sym = ''.join('%s %06o\n' % (name, addr)
                  for name, addr in addresses.items())
    transcript = ('INIT V1\nSFP\nHALT instruction, PC: 022650\n' +
                  ''.join('%06o:\t%012o\n' % (addresses[name], value)
                          for name, value in zip(LABELS, EXPECTED)) +
                  'Goodbye\n')
    decode_v1796(sym, transcript)
    bad = (
        (sym, transcript.replace('SFP', 'SF')),
        (sym, transcript.replace('SFP', 'FP')),
        (sym, transcript.replace('HALT instruction', 'Stopped')),
        (sym, transcript.replace('Goodbye', '')),
        (sym, transcript.replace('%012o' % 10, '%012o' % 9)),
        (sym, transcript.replace('%012o' % 1, '%012o' % 2, 1)),
        (sym, transcript.replace('INIT V1', 'INIT V1\n!7')),
        (sym.replace('k04_session_bad_v1796', 'bad_v1796'), transcript),
    )
    for index, args in enumerate(bad):
        try:
            decode_v1796(*args)
        except ValueError:
            continue
        raise AssertionError('negative control %d passed' % index)
    print('v1796 positive and %d negative verifier controls PASS' %
          len(bad))


def main(argv):
    if argv == ['--self-test']:
        self_test()
        return 0
    if len(argv) != 3:
        print('usage: verify-v1796.py --self-test | MAP SIMH DISK',
              file=sys.stderr)
        return 2
    result = decode_v1796(Path(argv[0]).read_text(),
                          Path(argv[1]).read_text(errors='replace'))
    print('K04 v1796 physical FILE/HUP counters:', result)
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', argv[2]],
                          capture_output=True, text=True)
    print((fsck.stdout + fsck.stderr).strip())
    if fsck.returncode or 'state=CLEAN' not in fsck.stdout + fsck.stderr:
        raise ValueError('guest D6FS is not CLEAN')
    print('K04 v1796 fatal FILE/HUP physical acceptance PASS')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError) as exc:
        print('K04 v1796 NOT ACCEPTED:', exc, file=sys.stderr)
        sys.exit(1)
