#!/usr/bin/env python3
"""Reject DCT-starving global PI masking in the BRK MM/APR transaction."""
import os
from pathlib import Path

root = Path(os.environ.get('DAIMOS_REPO', str(Path.home() / 'git/DAIMOS')))
src = (root / 'system/kernel/proc/vm_pdp6.s').read_text()
section = src.split('vm_brk_resize:', 1)[1].split('/**', 1)[0]


def verify(s):
    """Three lock entries and four restores must preserve PI3/PI5."""
    assert s.count('cono    0004,001002') == 3
    assert s.count('cono    0004,002002') == 4
    assert s.count('trne    1,000002') == 3
    assert s.count('trne    3,000002') == 1
    assert 'cono    0004,000400' not in s
    assert 'cono    0004,000200' not in s
    assert 'trne    1,000200' not in s
    assert 'trne    3,000200' not in s
    for label in ('vm_brk_find_extent:', 'vm_brk_fallback:',
                  'vm_brk_full_alloc:', 'vm_brk_commit:',
                  'vm_brk_return_commit:'):
        assert label in s


verify(section)
for old, new in (
    ('cono    0004,001002', 'cono    0004,000400'),
    ('cono    0004,002002', 'cono    0004,000200'),
    ('trne    1,000002', 'trne    1,000200'),
    ('trne    3,000002', 'trne    3,000200'),
):
    mutant = section.replace(old, new, 1)
    try:
        verify(mutant)
    except AssertionError:
        continue
    raise SystemExit('FAIL: unsafe PI mutant accepted')
print('v1744: BRK PI6-only MM/APR transaction and four unsafe mutants PASS')
