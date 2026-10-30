#!/usr/bin/env python3
"""Check actual resident victim swap requirements from a native v762 trace."""
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    sys.exit('usage: daimos-mm-swap-victim-footprints-check-v762.py trace.log')
text = Path(sys.argv[1]).read_text()
m = {int(a, 8): int(v, 8) for a, v in re.findall(
    r'^([0-7]+):\s+([0-7]{12})', text, re.MULTILINE)}
needed = [0o20604, 0o20267, 0o20610, 0o20627, 0o20630]
if any(a not in m for a in needed):
    sys.exit('v762: missing process/record/capacity data')
base, records, high = (m[a] for a in needed[:3])
free_blocks = m[0o20627] - m[0o20630]
resident = []
for slot in range(1, high):
    off = base + 3 * slot
    if any(a not in m for a in (off, off + 1, off + 2, records + slot)):
        sys.exit('v762: incomplete process/record data at slot %d' % slot)
    extent = m[off + 1]
    image_words = extent >> 18
    if not image_words or not (extent & 0o777777):
        continue
    backing = m[records + slot]
    pure_words = (backing >> 22) & 0o37777
    omitted = ((0o20 + pure_words) // 0o200) * 0o200 if pure_words else 0
    if omitted > image_words or image_words % 0o200:
        sys.exit('v762: invalid image/PURE layout at slot %d' % slot)
    required = (image_words - omitted) // 0o200
    resident.append((slot, required, omitted))
if not resident:
    sys.exit('v762: no resident images observed')
possible = [slot for slot, blocks, _ in resident if blocks <= free_blocks]
print('v762: free swap blocks=%d; resident candidates=%s' %
      (free_blocks, ','.join('%d:%d' % (s, b) for s, b, _ in resident)))
if possible:
    sys.exit('v762: some resident images fit by total capacity: %s' % possible)
if len(resident) != 9 or free_blocks != 176 or any(
    blocks != 208 or omitted != 0 for _, blocks, omitted in resident):
    sys.exit('v762: native result differs from reference failure signature')
print('v762: PASS: all nine resident images need 208 blocks, only 176 free')
