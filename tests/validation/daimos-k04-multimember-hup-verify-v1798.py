#!/usr/bin/env python3
"""Read-only booted PDP-6 multi-member HUP and refused FILE verifier.

Usage: verify-v1798.py --self-test | SYMBOLS SIMH_LOG DISK_DIR
"""
from pathlib import Path
import re
import subprocess
import sys


FIELDS = ('sync_calls', 'sync_refused', 'sync_delegated',
          'sync_mismatch', 'hup_calls', 'hup_fails', 'hup_success',
          'hup_bad', 'hup_targets', 'hup_protected')
SYMBOLS = tuple('k04_' + field + '_v1798' for field in FIELDS)


def decode_v1798(map_text, simh_text):
    labels = {}
    for name, address in re.findall(
            r'(?m)^([A-Za-z_][A-Za-z_0-9]*)\s+([0-7]+)\s*$', map_text):
        if name in labels:
            raise ValueError('duplicate physical witness label')
        labels[name] = int(address, 8)
    if set(labels) != set(SYMBOLS) or len(set(labels.values())) != 10:
        raise ValueError('incomplete or aliased K04 v1798 witness map')

    pos = simh_text.rfind('HALT instruction, PC:')
    if pos < 0 or 'Goodbye' not in simh_text[pos:]:
        raise ValueError('no complete normal guest HALT')
    out = simh_text[:pos].replace('\r', '')
    if 'UUO 000000000006' in out or '!' in out:
        raise ValueError('guest diagnostic error or UUO')
    if not re.search(r'(?m)S\s*H\s*P\s*$', out):
        raise ValueError('no ordered sleeping/HUP-pending/WAIT-complete proof')

    physical = {}
    for address, word in re.findall(
            r'(?m)^([0-7]+):[ \t]*([0-7]{12})\r?$',
            simh_text[pos:]):
        addr = int(address, 8)
        if addr in physical:
            raise ValueError('duplicate post-HALT physical witness')
        physical[addr] = int(word, 8)
    try:
        raw = tuple(physical[labels[name]] for name in SYMBOLS)
    except KeyError:
        raise ValueError('missing physical witness')
    words = dict(zip(FIELDS, raw))
    if (words['sync_calls'] != 11 or words['sync_refused'] != 10 or
            words['sync_delegated'] != 1 or words['sync_mismatch'] != 0):
        raise ValueError('wrong matching FD6 VFS refusal counts: %r' %
                         (words,))
    if (words['hup_calls'] < 2 or words['hup_fails'] < 1 or
            words['hup_success'] != 1 or words['hup_bad'] != 0 or
            words['hup_targets'] < 1 or words['hup_protected'] < 1):
        raise ValueError('HUP retry, TTY hold or fatal owner proof failed: %r' %
                         (words,))
    if words['hup_calls'] != words['hup_fails'] + words['hup_success']:
        raise ValueError('unaccounted session teardown call')
    return words


def self_test():
    syms = dict((name, 0o25030 + i) for i, name in enumerate(SYMBOLS))
    mp = ''.join('%s %06o\n' % (name, addr)
                 for name, addr in syms.items())
    vals = (11, 10, 1, 0, 8, 7, 1, 0, 7, 6)
    simh = ('INIT V1\nSHP\nHALT instruction, PC: 022650\n' +
            ''.join('%06o:\t%012o\n' % (syms[name], word)
                    for name, word in zip(SYMBOLS, vals)) +
            'Goodbye\n')
    decode_v1798(mp, simh)
    bad = (
        (mp, simh.replace('SHP', 'SP')),
        (mp, simh.replace('SHP', 'HSP')),
        (mp, simh.replace('HALT instruction', 'Stop')),
        (mp, simh.replace('Goodbye', '')),
        (mp, simh.replace('INIT V1', 'INIT V1\n!a')),
        (mp, simh.replace('%012o' % 10, '%012o' % 9)),
        (mp, simh.replace('%012o' % 11, '%012o' % 12)),
        (mp, simh.replace('%012o' % 6, '%012o' % 0)),
        (mp, simh.replace('%012o' % 8, '%012o' % 9)),
        (mp.replace(SYMBOLS[-1], 'missing_label'), simh),
    )
    for index, args in enumerate(bad):
        try:
            decode_v1798(*args)
        except ValueError:
            continue
        raise AssertionError('v1798 negative control %d passed' % index)
    print('v1798 positive + %d negative controls PASS' % len(bad))


def main(argv):
    if argv == ['--self-test']:
        self_test()
        return 0
    if len(argv) != 3:
        print('usage: verify-v1798.py --self-test | MAP SIMH DISK',
              file=sys.stderr)
        return 2
    result = decode_v1798(Path(argv[0]).read_text(),
                          Path(argv[1]).read_text(errors='replace'))
    print('K04 v1798 FILE/HUP witnesses:', result)
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', argv[2]],
                          capture_output=True, text=True)
    out = fsck.stdout + fsck.stderr
    print(out.strip())
    if fsck.returncode or 'state=CLEAN' not in out:
        raise ValueError('root D6FS not CLEAN')
    print('K04 v1798 physical multi-member HUP recovery PASS')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError) as exc:
        print('K04 v1798 NOT ACCEPTED:', exc, file=sys.stderr)
        sys.exit(1)
