#!/usr/bin/env python3
"""Check exact symbol selection and reject stale or ambiguous maps."""

from pathlib import Path
import runpy


root = Path(__file__).parent
api = runpy.run_path(str(root / 'daimos-f07-pi-map-probe-v1249.py'))
names = api['SYMBOLS']
raw = ''.join('%s %06o\n' % (name, 0o20000 + i)
              for i, name in enumerate(names))
symbols = api['read_symbols'](raw)
script = api['generate']('deposit 0 0\ngo 020\nexamine 0\n', symbols)
assert script.count('go 020\n') == 1
for i, name in enumerate(names):
    assert ('; v1249 ' + name + '\nexamine %06o\n' %
            (0o20000 + i)) in script
assert script.endswith('examine 0\n')
for broken in (raw + raw.splitlines()[0] + '\n',
               raw.replace(names[0] + ' ', 'wrong_name ', 1),
               raw.replace('%06o' % 0o20000, 'INVALID', 1)):
    try:
        api['read_symbols'](broken)
    except ValueError:
        pass
    else:
        raise AssertionError('bad map unexpectedly accepted')
try:
    api['generate']('go 020\ngo 020\n', symbols)
except ValueError:
    pass
else:
    raise AssertionError('ambiguous boot go unexpectedly accepted')
print('v1249: exact map lookup, stage injection, four mutants PASS')
