#!/usr/bin/env python3
"""Strict completed F07 no-partner recovery with a real user releaser.

Unlike the v1303 ordinary-swap classifier, distinguish failed
reclamation attempts (proc_swap_out_fail) from terminal swap-in
failure. A failed victim refusal is allowed only under independently
accounted reclaim_fail, with complete normal HALT/cleanup evidence.
"""

from pathlib import Path
import re
import runpy
import sys

HERE = Path(__file__).resolve().parent
SRC = runpy.run_path(str(HERE / 'daimos-swap-no-partner-physical-v1303.py'))
MM = runpy.run_path(str(HERE / 'daimos-f07-mm-peak-verify-v1203.py'))
HALF = 0o777777


def verify_swap(c, a, n):
    if c['fallback'] or c['swapin_fail']:
        raise ValueError('fallback or fatal swap-in failure')
    if not c['pressure'] or not c['cooldown'] or c['exchanged']:
        raise ValueError('genuine non-exchange no-partner case missing')
    if (c['pressure'] != c['swapin_pressure'] or
            c['pressure'] != c['cooldown'] + c['exchanged'] or
            c['pressure'] != a['calls']):
        raise ValueError('MM resource pressure accounting mismatch')
    failure = a['error']
    if failure & (1 << 35):
        failure -= 1 << 36
    if failure not in (-1, -2, -3) or not a['requested']:
        raise ValueError('no typed physical MM shortage observed')
    if not c['reclaim_fail'] or c['swapout_fail'] > c['reclaim_fail']:
        raise ValueError('unaccounted failed swap-out or reclaim')
    if (not c['swapout_ok'] or not c['swapin_ok'] or
            c['swapin_ok'] != c['restored']):
        raise ValueError('restoration/reclamation not balanced')
    for name in ('f07s_final_swap_blocks',
                 'f07s_final_backstore_used'):
        if n.get(name) != 0:
            raise ValueError('unreleased backing: ' + name)


def verify_owner(snapshot, final):
    mm = MM['decode_snapshot'](snapshot)
    if any(final.get(key) != value for key, value in (
            ('prepared', 4), ('freed', 4), ('count', 0), ('error', 0),
            ('released', 1), ('spinner_base', 0))):
        raise ValueError('real MM owner/pin cleanup incomplete')
    if not (0 < final.get('release_pressure', 0) < 0o1000000):
        raise ValueError('releaser did not observe real no-partner pressure')
    for i in range(mm['extent_count']):
        meta = snapshot['extent%d' % (2 * i + 1)]
        if ((meta >> 18) & 7) == 3 and (meta & HALF) == 0o75:
            raise ValueError('test owner still present after release')
    if mm['process_extents'] < 2:
        raise ValueError('independent user processes missing')
    return mm


def get_final(addresses, output):
    mapping = dict(line.split() for line in
                   Path(addresses).read_text().splitlines())
    text = Path(output).read_text(errors='replace')
    final = {}
    for label in ('f07h_prepared', 'f07h_freed', 'f07h_count',
                  'f07h_error', 'f07r_released',
                  'f07r_spinner_base', 'f07r_release_pressure'):
        addr = int(mapping[label], 8)
        found = re.findall(r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)' %
                           addr, text)
        if len(found) != 1:
            raise ValueError('missing or duplicate physical witness ' + label)
        final[label[5:]] = int(found[0], 8)
    return final


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1336 ADDRESSES COMPLETED-SIMH-OUTPUT')
    addresses, output = sys.argv[1:]
    text = Path(output).read_text(errors='replace')
    if ('HALT instruction, PC:' not in text or 'KWP' not in text or
            text.count('&') != 1 or 'Goodbye' not in text):
        raise ValueError('full guest HALT, milestones or release absent')
    counts, alloc, names = SRC['decode'](addresses, output)
    verify_swap(counts, alloc, names)
    snapshot = MM['load_observation'](addresses, output)
    final = get_final(addresses, output)
    mm = verify_owner(snapshot, final)
    for name, mutation in (
            ('pressure-count', ('pressure', counts['pressure'] + 1)),
            ('fatal-restore', ('swapin_fail', 1)),
            ('unaccounted-swapout',
             ('swapout_fail', counts['reclaim_fail'] + 1)),
            ('missing-cooldown', ('cooldown', 0))):
        bad = dict(counts)
        bad[mutation[0]] = mutation[1]
        try:
            verify_swap(bad, alloc, names)
        except ValueError:
            continue
        raise AssertionError('unsafe mutation accepted: ' + name)
    for name, key, value in (
            ('owner-leak', 'count', 1),
            ('lost-owner-free', 'freed', 3),
            ('unobserved-pressure', 'release_pressure', 0),
            ('spinner-pin-leak', 'spinner_base', 1)):
        bad = dict(final, **{key: value})
        try:
            verify_owner(snapshot, bad)
        except ValueError:
            continue
        raise AssertionError('unsafe mutation accepted: ' + name)
    print('v1336: 256K booted real-MM no-partner independent user '
          'release and complete backstore/owner/pin cleanup PASS')
    print('v1336: pressure=%d cooldown=%d swapout=%d swapin=%d '
          'release_at=%d process_extents=%d' %
          (counts['pressure'], counts['cooldown'], counts['swapout_ok'],
           counts['swapin_ok'], final['release_pressure'],
           mm['process_extents']))


if __name__ == '__main__':
    main()
