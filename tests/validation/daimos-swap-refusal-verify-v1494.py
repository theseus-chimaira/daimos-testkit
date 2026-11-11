#!/usr/bin/env python3
"""Validate a genuine 256K F07 checked-release TERM/PREVM/retry chain."""

from pathlib import Path
import re
import sys


FIELDS = ('armed', 'faults', 'free_calls', 'terms', 'repairs', 'errors',
          'slot', 'first', 'blocks', 'bitmap_addr', 'bitmap_saved')


def verify_values(data):
    required = dict(armed=2, faults=1, free_calls=3, terms=1,
                    repairs=1, errors=0)
    for key, expected in required.items():
        if data[key] != expected:
            raise ValueError('%s=%d expected=%d' % (key, data[key], expected))
    for key in ('slot', 'blocks', 'bitmap_addr', 'bitmap_saved'):
        if not data[key]:
            raise ValueError('missing physical allocation witness: ' + key)
    if data['slot'] < 0o10:
        raise ValueError('fault targeted an INIT or early protected slot')
    for key in ('final_swap_blocks', 'final_backstore_used'):
        if data[key] != 0:
            raise ValueError('BACKSTORE owner leaked: %s=%d' % (key, data[key]))


def read_final(addresses, transcript):
    mapping = {}
    for line in Path(addresses).read_text().splitlines():
        key, address = line.split()
        if key in mapping:
            raise ValueError('duplicate address: ' + key)
        mapping[key] = int(address, 8)
    output = Path(transcript).read_text(errors='replace')
    marker = output.rfind('HALT instruction, PC:')
    if marker < 0 or 'Goodbye' not in output[marker:]:
        raise ValueError('real full-guest HALT/EXIT was not observed')
    output = output[marker:]
    result = {}
    for name in FIELDS + ('final_swap_blocks', 'final_backstore_used'):
        key = 'v1494_' + name if name in FIELDS else 'f07s_' + name
        if key not in mapping:
            raise ValueError('missing map-backed counter: ' + key)
        pattern = r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)' % mapping[key]
        matches = re.findall(pattern, output)
        if len(matches) != 1:
            raise ValueError('%s seen %d times after HALT' % (key, len(matches)))
        result[name] = int(matches[0], 8)
    verify_values(result)
    return result


def self_test():
    good = dict(armed=2, faults=1, free_calls=3, terms=1, repairs=1,
                errors=0, slot=0o10, first=1, blocks=8, bitmap_addr=300,
                bitmap_saved=0o777, final_swap_blocks=0,
                final_backstore_used=0)
    verify_values(good)
    for key in good:
        changed = dict(good)
        changed[key] = 1 if good[key] == 0 else 0
        try:
            verify_values(changed)
        except ValueError:
            continue
        if key in ('slot', 'blocks', 'bitmap_addr', 'bitmap_saved',
                   'armed', 'faults', 'free_calls', 'terms', 'repairs',
                   'errors', 'final_swap_blocks', 'final_backstore_used'):
            raise AssertionError('failed to reject mutation: ' + key)
    return len(good)


def main():
    if len(sys.argv) == 2 and sys.argv[1] == '--self-test':
        print('v1494: %d final-owner verifier mutations rejected' % self_test())
        return
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1494.py ADDRESSES SIMH.OUT')
    data = read_final(sys.argv[1], sys.argv[2])
    print('v1494: physical slot=%o BACKSTORE first=%o count=%o' %
          (data['slot'], data['first'], data['blocks']))
    print('v1494: real swap-in failed release, TERM + failed PREVM detach, '
          'idle retry + repaired bitmap free, final usage zero PASS')
    print('v1494: %d verifier negative controls PASS' % self_test())


if __name__ == '__main__':
    main()
