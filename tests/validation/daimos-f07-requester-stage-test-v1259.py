#!/usr/bin/env python3
"""Negative-control checks for the exact C89 requester instrumentation."""

from pathlib import Path
import importlib.util
import os
import tempfile

selfdir = Path(__file__).resolve().parent
source_path = selfdir / 'daimos-oom-requester-live-v1075.c'
script_path = selfdir / 'daimos-f07-requester-stage-v1259.py'
spec = importlib.util.spec_from_file_location('f07_requester_v1259', script_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
source = source_path.read_text()
instrumented = module.inject(source)
assert instrumented.count("dsys_writechar(1, '&')") == 1
assert instrumented.count("dsys_writechar(1, '=')") == 1
assert instrumented.count('v1259_brk_result = dsys_brk(') == 1
assert source.count('v1259_brk_result') == 0
assert instrumented.count('dsys_brk(V1075_BRK_REQUEST)') == 1
for broken in (source.replace('if (dsys_brk(V1075_BRK_REQUEST)',
                              'if (other_brk(V1075_BRK_REQUEST)'),
               source.replace("TEST_SIX6('O', ' ', ' ', ' ', ' ', ' ')",
                              "TEST_SIX6('P', ' ', ' ', ' ', ' ', ' ')", 1)):
    try:
        module.inject(broken)
    except ValueError:
        pass
    else:
        raise AssertionError('v1259: malformed guest was accepted')
try:
    module.inject(instrumented)
except ValueError:
    pass
else:
    raise AssertionError('v1259: duplicate instrumentation accepted')

with tempfile.TemporaryDirectory(prefix='daimos-v1259-',
                                 dir=os.environ.get('TMPDIR')) as directory:
    target = Path(directory) / 'requester-v1259.c'
    assert not target.exists()
    target.write_text(instrumented)
    assert target.read_text() == instrumented
print('v1259: exact requester pre/post BRK C89 markers and three mutants PASS')
