#!/usr/bin/env python3
"""Verify map-selected stack/event snapshots and four negative fixtures."""

from pathlib import Path
import runpy


root = Path(__file__).parent
v1250 = runpy.run_path(str(root / 'daimos-f07-slot0-event-v1250.py'))
v1249 = runpy.run_path(str(root / 'daimos-f07-pi-map-probe-v1249.py'))
names = list(v1249['SYMBOLS']) + list(v1250['NAMES'])
raw = ''.join('%s %06o\n' % (name, 0o20000 + i)
              for i, name in enumerate(names))
boot = 'deposit 0 0\ngo 020\nexamine 1\n'
result = v1250['produce'](boot, raw)
for i, name in enumerate(v1250['NAMES']):
    assert ('; v1250 %s\nexamine %06o\n' %
            (name, 0o20000 + len(v1249['SYMBOLS']) + i)) in result
assert result.count('go 020\n') == 1
assert 'examine 046000-050000\n' in result
assert result.endswith('examine 1\n')

for bad in (
    raw.replace(v1250['NAMES'][0] + ' ', 'unknown ', 1),
    raw + raw.splitlines()[-1] + '\n',
    raw.replace('%06o' % (0o20000 + len(v1249['SYMBOLS'])),
                'not_octal', 1),
    raw,
):
    try:
        v1250['produce']('go 020\ngo 020\n' if bad is raw else boot, bad)
    except ValueError:
        pass
    else:
        raise AssertionError('v1250: invalid diagnostic accepted')
print('v1250: exact device/stack map, four negative fixtures PASS')
