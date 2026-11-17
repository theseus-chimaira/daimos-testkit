#!/usr/bin/env python3
"""Fail-closed rejection of a real bounded bootstrap-only opcode profile."""
import importlib.util
from pathlib import Path
import os
import tempfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('gate', ROOT/'tools/check-pdp6-linked-profile-v1.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
with tempfile.TemporaryDirectory(prefix='pdp6-linked-profile-v1.',
         dir=os.environ.get('TMPDIR', str(Path.home()/'tmp'))) as tmp:
    path = Path(tmp)/'bootstrap.log'
    path.write_text('Step expired, OPCOUNT: 0\nPC:\t000100\n'
                    'OPCOUNT[0]:\t00000000000000000000\n'
                    'OPCOUNT[1]-OPCOUNT[171]: same as above\n'
                    'OPCOUNT[172]:\t00000000000000000042\n'
                    'OPCOUNT[173]:\t00000000000000000000\n'
                    'OPCOUNT[174]-OPCOUNT[184]: same as above\n'
                    'OPCOUNT[185]:\t00000000000000000042\n'
                    'OPCOUNT[186]:\t00000000000000000042\n'
                    'OPCOUNT[187]:\t00000000000000000000\n'
                    'OPCOUNT[188]-OPCOUNT[511]: same as above\n')
    assert len(gate.report.read_counts(path)) == 512
    try:
        gate.check(path)
    except ValueError as exc:
        assert 'diversity' in str(exc)
    else:
        raise AssertionError('three-opcode bootstrap incorrectly accepted')
    path.write_text('OPCOUNT[172]:\t00000000000000000042\n')
    try:
        gate.check(path)
    except ValueError:
        pass
    else:
        raise AssertionError('incomplete profile incorrectly accepted')
print('SIMH bounded bootstrap profile rejection v1: PASS')
