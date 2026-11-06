#!/usr/bin/env python3
"""Verify exact slot-0 wait values and active/pending descriptor mutants."""

from pathlib import Path
import runpy


api = runpy.run_path(str(Path(__file__).with_name(
    'daimos-f07-slot0-wait-report-v1250.py')))
fields = api['FIELDS']
addr = ''.join('f07wait_%s %06o\n' % (name, 0o23000 + i)
               for i, name in enumerate(fields))
data = {name: 0 for name in fields}
data['calls'] = 4
data['event'] = 0o47610
data['drm_active'] = (0o454 << 18) | 0o47606
dump = ''.join('%o: %012o\n' % (0o23000 + i, data[name])
               for i, name in enumerate(fields))
parsed = api['read_observation'](addr, dump)
assert parsed == data
assert 'active DRM' in api['classify'](parsed)
parsed['drm_active'] = 0
parsed['drm_pending'] = 0o47606
assert 'pending DRM' in api['classify'](parsed)
parsed['drm_pending'] = 0
assert 'no matching DRM' in api['classify'](parsed)
assert api['closest_symbol']('lower 0100\nhigher 0200\n', 0o203) == 'higher+3'
for broken_addr, broken_dump in ((addr + addr.splitlines()[0] + '\n', dump),
                                 (addr.replace('f07wait_calls', 'unknown'), dump),
                                 (addr, dump + dump.splitlines()[0] + '\n')):
    try:
        api['read_observation'](broken_addr, broken_dump)
    except ValueError:
        pass
    else:
        raise AssertionError('malformed observation unexpectedly accepted')
print('v1250: native wait snapshot parser and six negative branches PASS')
