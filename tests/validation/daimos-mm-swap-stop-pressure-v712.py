#!/usr/bin/env python3
"""Verify the stopped-job pressure oracle passes an array and count."""
from pathlib import Path
import re
import sys

source=Path(sys.argv[1]).read_text()
body=source.split('run_stopped_job_case(void)',1)[1]
assert re.search(r'int pressure\[2\];',body)
assert re.search(r'pressure\[0\]\s*=\s*pressure_a;',body)
assert re.search(r'pressure\[1\]\s*=\s*pressure_b;',body)
assert re.search(r'target_is_swapped\(\(unsigned int\)job,\s*pressure,\s*2U\)',body)
assert not re.search(r'target_is_swapped\(\(unsigned int\)job,\s*\(unsigned int\)',body)
print('v712: stopped-job pressure array contract PASS')
