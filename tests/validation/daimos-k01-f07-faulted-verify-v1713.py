#!/usr/bin/env python3
"""Strict *faulted* F07 ownership and independent-release acceptance.

The ordinary v1336 clean guest intentionally prohibits any terminal
swap-in failure. The v1713 injected guest intentionally creates two
failed restores of one exact DISK run, then repairs the injected bit.
Never replace the ordinary baseline verifier. This separate verifier
requires exactly accounted faults, an unchanged original DISK owner,
the safe deferred TERM witness, and full physical cleanup. It reuses
the original source-linked v1336 independent MM-owner verification.
"""

from pathlib import Path
import re
import runpy
import sys


HERE = Path(__file__).resolve().parent
NORMAL = runpy.run_path(str(HERE / 'daimos-swap-independent-release-verify-v1336.py'))
SWAP = runpy.run_path(str(HERE / 'daimos-swap-no-partner-physical-v1303.py'))
MM = runpy.run_path(str(HERE / 'daimos-f07-mm-peak-verify-v1203.py'))

FAULT_FIELDS = ('armed', 'faults', 'free_calls', 'terms', 'repairs',
                'errors', 'slot', 'first', 'blocks', 'bitmap_addr',
                'bitmap_saved')


def check_fault(c, a, n, f):
    """Require the actual two refused frees and one exact successful retry."""
    required = {'armed': 2, 'faults': 1, 'free_calls': 3,
                'terms': 2, 'repairs': 1, 'errors': 0}
    for key, expected in required.items():
        if f[key] != expected:
            raise ValueError('F07 fault witness %s=%d, expected %d' %
                             (key, f[key], expected))
    if f['slot'] < 0o10 or not all(f[name] != 0 for name in
                                  ('blocks', 'bitmap_addr', 'bitmap_saved')):
        raise ValueError('no exact unprotected physical DISK-run identity')
    # The two failed `backstore_free` calls must each cause a checked
    # failed restore, not an unrelated or unaccounted fatal restore.
    if c['swapin_fail'] != f['free_calls'] - f['repairs'] or \
            c['swapin_fail'] != f['terms']:
        raise ValueError('failure/event count not bound to injected run')
    if (c['fallback'] or not c['pressure'] or not c['cooldown'] or
            c['exchanged'] or c['pressure'] != c['swapin_pressure'] or
            c['pressure'] != c['cooldown'] + c['exchanged'] or
            c['pressure'] != a['calls']):
        raise ValueError('real allocator pressure/no-partner mismatch')
    if not a['requested']:
        raise ValueError('typed MM pressure did not request physical words')
    mm_error = a['error']
    if mm_error & (1 << 35):
        mm_error -= 1 << 36
    if mm_error not in (-1, -2, -3):
        raise ValueError('real MM allocator pressure type incorrect')
    if (not c['swapout_ok'] or not c['swapin_ok'] or
            c['swapin_ok'] != c['restored'] or
            not c['reclaim_fail'] or
            c['swapout_fail'] > c['reclaim_fail']):
        raise ValueError('real successful swap/reclaim accounting mismatch')
    for name in ('f07s_final_swap_blocks', 'f07s_final_backstore_used'):
        if n.get(name) != 0:
            raise ValueError('final physical backing leak: ' + name)


def read_fault(addresses, output):
    mapping = {}
    for row in Path(addresses).read_text().splitlines():
        name, address = row.split()
        if name in mapping:
            raise ValueError('duplicate source map name ' + name)
        mapping[name] = int(address, 8)
    transcript = Path(output).read_text(errors='replace')
    at = transcript.rfind('HALT instruction, PC:')
    if at < 0 or 'Goodbye' not in transcript[at:]:
        raise ValueError('no completed 256K guest HALT/EXIT')
    transcript = transcript[at:]
    counters = {}
    for field in FAULT_FIELDS:
        label = 'v1494_' + field
        if label not in mapping:
            raise ValueError('missing physical witness ' + label)
        pattern = r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)' % mapping[label]
        values = re.findall(pattern, transcript)
        if len(values) != 1:
            raise ValueError('missing/duplicate post-HALT ' + label)
        counters[field] = int(values[0], 8)
    return counters


def negative_tests():
    c = dict(pressure=1, fallback=0, reclaim_fail=1, swapout_ok=34,
             swapout_fail=1, swapin_ok=34, swapin_pressure=1,
             swapin_fail=2, cooldown=1, exchanged=0, restored=34)
    a = dict(calls=1, error=(1 << 36) - 1, requested=0o64000)
    n = dict(f07s_final_swap_blocks=0, f07s_final_backstore_used=0)
    f = dict(armed=2, faults=1, free_calls=3, terms=2, repairs=1,
             errors=0, slot=0o10, first=0, blocks=0o330,
             bitmap_addr=0o52770, bitmap_saved=0o740000000000)
    check_fault(c, a, n, f)
    tests = (
        ('missing-fault', 'fault', 'faults', 0),
        ('premature-terminal-event', 'fault', 'terms', 1),
        ('unrepaired-bitmap', 'fault', 'repairs', 0),
        ('false-error-free', 'fault', 'errors', 1),
        ('uncommitted-repair', 'fault', 'armed', 1),
        ('extra-free', 'fault', 'free_calls', 4),
        ('protected-owner', 'fault', 'slot', 0o7),
        ('missing-backing', 'fault', 'blocks', 0),
        ('missing-bit', 'fault', 'bitmap_saved', 0),
        ('unexpected-fatal', 'swap', 'swapin_fail', 3),
        ('unbalanced-restores', 'swap', 'restored', 33),
        ('unaccounted-pressure', 'swap', 'pressure', 2),
        ('fake-fallback', 'swap', 'fallback', 1),
        ('missing-reclaim-failure', 'swap', 'reclaim_fail', 0),
        ('untyped-MM-error', 'allocation', 'error', (1 << 36) - 5),
        ('backing-owner-leak', 'backing', 'f07s_final_backstore_used', 1),
    )
    for title, category, key, changed in tests:
        cc, aa, nn, ff = map(dict, (c, a, n, f))
        target = {'swap': cc, 'allocation': aa,
                  'backing': nn, 'fault': ff}[category]
        target[key] = changed
        try:
            check_fault(cc, aa, nn, ff)
        except ValueError:
            continue
        raise AssertionError('accepted unsafe fault mutation: ' + title)
    # The unmodified v1336 baseline must STILL reject the same fatal
    # evidence. Its use for a faulted guest was a contradictory gate.
    try:
        NORMAL['verify_swap'](c, a, n)
    except ValueError as exc:
        if 'fatal swap-in failure' not in str(exc):
            raise
    else:
        raise AssertionError('baseline v1336 silently accepted injected fatal')
    return len(tests)


def main():
    if sys.argv[1:] == ['--self-test']:
        print('v1713: %d independent unsafe fault mutations rejected' %
              negative_tests())
        return
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1713.py ADDRESSES SIMH.OUT')
    addresses, output = sys.argv[1:]
    text = Path(output).read_text(errors='replace')
    if 'KWP' not in text or text.count('&') != 1 or \
            'HALT instruction, PC:' not in text:
        raise ValueError('incomplete original F07 requester/witness markers')
    counts, alloc, names = SWAP['decode'](addresses, output)
    fault = read_fault(addresses, output)
    check_fault(counts, alloc, names, fault)
    snapshot = MM['load_observation'](addresses, output)
    final = NORMAL['get_final'](addresses, output)
    physical = NORMAL['verify_owner'](snapshot, final)
    print('v1713: faulted F07 exact DISK slot=%o run=%o:%o, '
          'two deferred TERM events and repaired backing PASS' %
          (fault['slot'], fault['first'], fault['blocks']))
    print('v1713: real MM owner release, %d original process extents, '
          'balanced successful restores, final BACKSTORE zero PASS' %
          physical['process_extents'])
    print('v1713: %d unsafe mutation controls PASS' % negative_tests())


if __name__ == '__main__':
    main()
