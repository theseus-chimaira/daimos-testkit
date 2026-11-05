#!/usr/bin/env python3
"""Validate real-time protected-slot and fatal-victim snapshots."""

from pathlib import Path
import re
import sys

addresses = Path(sys.argv[1]).read_text().splitlines()
output = Path(sys.argv[2]).read_text(errors='replace')
enabled = sys.argv[3] == '1'
observed = {}
for line in addresses:
    name, addr = line.split()
    if not name.startswith('e12_'):
        continue
    pattern = (r'(?m)^\s*0*' + re.escape(addr.lstrip('0')) +
               r'\s*:\s*([0-7]+)')
    values = re.findall(pattern, output)
    if len(values) != 1:
        raise SystemExit('v1159: missing or duplicate ' + name)
    observed[name[4:]] = int(values[0], 8)

expected = {
    'requester': 3,
    'snapshots': 1,
    'error': 0,
    'selected': 3 if enabled else 0,
    'select_calls': 1 if enabled else 0,
}
for name, value in expected.items():
    if observed.get(name) != value:
        raise SystemExit('v1159: %s got %r, expected %r; %r' %
                         (name, observed.get(name), value, observed))
for name in ('init', 'witness', 'waiter', 'holder'):
    if (observed.get(name, -1) & 0o700000) != 0o300000:
        raise SystemExit('v1159: %s not sleeping: %r' % (name, observed))
if (observed.get('spinner', -1) & 0o700000) not in (0o200000, 0o300000):
    raise SystemExit('v1159: unrelated spinner not active: ' + repr(observed))

print('v1159: INIT, blocked witness, gateway waiter, spinner and '
      'in-flight original FS owner protected at genuine BRK OOM; '
      'only slot 3 selected for fatal retirement when enabled; '
      'kernel/slot-0 not selected; snapshots PASS:', observed)
