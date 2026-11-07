#!/usr/bin/env python3
"""Validate the observed v1322 failed owner admission, not swap liveness.

This verifier deliberately refuses to turn a real owner MM allocation
failure into evidence for proc_swap_in pressure. It reads the raw SIMH
post-HALT addresses instead of inferring failure from a shell exit.
"""

from pathlib import Path
import re
import sys


EXPECTED = {
    'f07h_count': 0,
    'f07h_prepared': 0,
    'f07h_freed': 0,
    'f07h_error': (1 << 36) - 1,
    'f07s_diag_pressure': 0,
    'f07s_diag_cooldown': 0,
    'f07s_diag_exchanged': 0,
    'f07a_calls': 0,
}


def check_counters(counters):
    for key, value in EXPECTED.items():
        if counters.get(key) != value:
            raise ValueError('unexpected %s: %r != %o' %
                             (key, counters.get(key), value))


def classify(address_path, simh_path):
    rows = [line.split() for line in address_path.read_text().splitlines()]
    if any(len(row) != 2 for row in rows):
        raise ValueError('invalid address manifest')
    addresses = dict(rows)
    if len(addresses) != len(rows):
        raise ValueError('duplicate address labels')
    text = simh_path.read_text(errors='replace')
    if '!t' not in text or 'HALT instruction, PC:' not in text:
        raise ValueError('guest did not halt on owner admission failure')

    counters = {}
    for label in EXPECTED:
        if label not in addresses:
            raise ValueError('missing manifest address ' + label)
        addr = int(addresses[label], 8)
        found = re.findall(r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)' %
                           addr, text)
        if len(found) != 1:
            raise ValueError('missing/duplicate final counter ' + label)
        counters[label] = int(found[0], 8)

    check_counters(counters)
    return counters


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1325.py ADDRESSES SIMH-TRANSCRIPT')
    addresses, transcript = (Path(arg) for arg in sys.argv[1:])
    counters = classify(addresses, transcript)
    # These controls must remain rejected even if the recognizable
    # console marker still occurs in a corrupted diagnostic record.
    for label, replacements in (
            ('accepted-owner', {'f07h_error': 0}),
            ('owner-leak', {'f07h_count': 1}),
            ('real-swapin-pressure', {'f07a_calls': 1}),
            ('fake-cooldown', {'f07s_diag_cooldown': 1})):
        mutant = dict(counters, **replacements)
        try:
            check_counters(mutant)
        except ValueError:
            continue
        raise AssertionError('accepted invalid counter mutation: ' + label)
    print('v1325: v1322 owner 8K admission failed; exact cleanup, '
          'zero real swap-in MM pressure/cooldowns verified')
    print('v1325: not no-partner evidence; no kernel fault inferred')


if __name__ == '__main__':
    main()
