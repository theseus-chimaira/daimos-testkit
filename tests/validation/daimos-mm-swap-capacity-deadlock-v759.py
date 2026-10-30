#!/usr/bin/env python3
"""Analyze the native v754 allocator/reclaim snapshot without new kernel RAM.

Input is a SIMH examine transcript from the fixed v754 diagnostic fixture.
This is a capacity diagnostic, not a scheduler-acceptance test.
"""
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    sys.exit('usage: daimos-mm-swap-capacity-deadlock-v759.py V754_TRACE_LOG')
text = Path(sys.argv[1]).read_text()
words = {int(a, 8): int(b, 8) for a, b in re.findall(
    r'^([0-7]+):\s+([0-7]{12})', text, re.MULTILINE)}
needed = [0o20152, 0o20220, 0o20224, 0o20225, 0o20627, 0o20630]
if any(a not in words for a in needed):
    sys.exit('v759: incomplete v754 native memory snapshot')
base = words[0o20220] & 0o777777
end = base + (words[0o20220] >> 18)
n = words[0o20224]
if words[0o20225] != 1 or n > words[0o20152] or n == 0:
    sys.exit('v759: bad arena or extent metadata')
previous, total_free, largest = base, 0, 0
for i in range(n):
    address = 0o20633 + 2 * i
    if address not in words or address + 1 not in words:
        sys.exit('v759: incomplete native extent table')
    descriptor = words[address]
    extent_base, extent_words = descriptor & 0o777777, descriptor >> 18
    if extent_base < previous or extent_base + extent_words > end:
        sys.exit('v759: invalid extent ordering/bounds')
    gap = extent_base - previous
    total_free += gap
    largest = max(largest, gap)
    previous = extent_base + extent_words
last = end - previous
total_free += last
largest = max(largest, last)
backstore_free = words[0o20627] - words[0o20630]
request_words = 0o64000
sector_words = 0o200
request_blocks = (request_words + sector_words - 1) // sector_words
assert total_free == 907 and largest == 760, (total_free, largest)
assert backstore_free == 176 and request_blocks == 208
assert backstore_free < request_blocks and largest < request_words
print('v759: native RAM/swap capacity deadlock reproduced;'
      ' free RAM=%d, largest gap=%d, swap blocks=%d/%d'
      % (total_free, largest, backstore_free, request_blocks))
