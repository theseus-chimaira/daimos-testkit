#!/usr/bin/env python3
"""Fail-closed tests for boot-stage evidence and complete dispatch count."""
import importlib.util
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('profile', ROOT/'tools/check-pdp6-kernel-boot-profile-v1.py')
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)
with tempfile.TemporaryDirectory() as tmp:
    path = Path(tmp)/'sample.log'
    rows = ['PDP6 simulator', 'DAIMON                              V0.5',
            'MACH                                PDP6',
            'CTY                                   OK',
            'BSET                              LOADED',
            'Step expired', 'PC: 025650']
    values = [n+1 if n < 16 else 0 for n in range(512)]
    rows.extend('OPCOUNT[%d]: %020d' % (i, n) for i,n in enumerate(values))
    raw = '\n'.join(rows)+'\n'
    path.write_text(raw)
    result = profile.analyze(path)
    assert result['active_opcode_count'] == 16
    assert result['counter_total'] == sum(values)
    for item in ('DAIMON', 'BSET', 'Step expired', 'MACH'):
        path.write_text(raw.replace(item, 'MISSING', 1))
        try:
            profile.analyze(path)
        except ValueError:
            pass
        else:
            raise AssertionError('invalid boot accepted: '+item)
    path.write_text('\n'.join(rows[:-1])+'\n')
    try:
        profile.analyze(path)
    except ValueError:
        pass
    else:
        raise AssertionError('incomplete OPCOUNT array accepted')
print('PDP-6 linked-kernel boot-stage histogram classifier v1: PASS')
