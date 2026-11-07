#!/usr/bin/env python3
"""Verify genuine process MM pins at F07 OOM and exact final unpin."""

from pathlib import Path
import re
import runpy
import sys


def verify(snapshot, final):
    module = runpy.run_path(str(Path(__file__).with_name(
        'daimos-f07-mm-peak-verify-v1203.py')))
    mm = module['decode_snapshot'](snapshot)
    expected = final.get('prepared')
    if not isinstance(expected, int) or not 2 <= expected <= 63:
        raise ValueError('fixture did not pin multiple actual residents')
    if (final.get('count') != 0 or final.get('error') != 0 or
            final.get('freed') != expected):
        raise ValueError('pins not unpinned exactly before teardown')
    pinned_process = 0
    for i in range(mm['extent_count']):
        meta = snapshot['extent%d' % (i * 2 + 1)]
        if (meta >> 18) & 7 != 1:
            continue
        pinned_process += bool((meta >> 21) & 0o377)
    if pinned_process < expected:
        raise ValueError('real MM pin footprint not present at BRK OOM')
    mm['test_process_pins'] = expected
    mm['pinned_process_extents_at_oom'] = pinned_process
    return mm


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1326 ADDRESSES SIMH-OUTPUT')
    module = runpy.run_path(str(Path(__file__).with_name(
        'daimos-f07-mm-peak-verify-v1203.py')))
    snapshot = module['load_observation'](sys.argv[1], sys.argv[2])
    addresses = dict(line.split() for line in
                     Path(sys.argv[1]).read_text().splitlines())
    transcript = Path(sys.argv[2]).read_text(errors='replace')
    final = {}
    for key in ('prepared', 'freed', 'count', 'error'):
        label = 'f07h_' + key
        addr = int(addresses[label], 8)
        found = re.findall(r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)' %
                           addr, transcript)
        if len(found) != 1:
            raise ValueError('invalid final counter ' + label)
        final[key] = int(found[0], 8)
    result = verify(snapshot, final)
    for name, other in (('missing-unpin', dict(final, freed=0)),
                        ('owner-leak', dict(final, count=1)),
                        ('pin-error', dict(final, error=1))):
        try:
            verify(snapshot, other)
        except ValueError:
            continue
        raise AssertionError('invalid pin accounting accepted: ' + name)
    print('v1326: production MM pins present for %d resident processes '
          'at BRK OOM; exact unpin before TERM/WAIT PASS' %
          result['test_process_pins'])


if __name__ == '__main__':
    main()
