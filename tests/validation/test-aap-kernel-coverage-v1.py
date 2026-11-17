#!/usr/bin/env python3
"""Regression for conservative AAP/kernel fixture evidence mapping."""
import importlib.util
from pathlib import Path

import os
root = Path(__file__).resolve().parents[2]
compiler_testkit = Path(os.environ.get('PDP10_TESTKIT_REPO',
                                       str(root.parent/'pdp10-testkit')))
path = compiler_testkit / 'tools/aap-kernel-coverage-v1.py'
spec = importlib.util.spec_from_file_location('aap_kernel_coverage_v1', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
matched = module.verified_family_names()
for opcode in ('move', 'movei', 'movem', 'jrst', 'pushj', 'popj',
               'blt', 'ldb', 'dpb', 'ildb', 'idpb', 'ibp',
               'caie', 'cain', 'came', 'camn', 'trne', 'trnn', 'tlne'):
    assert opcode in matched, ('unmapped registered guest evidence', opcode)
for opcode in ('cono', 'coni', 'div'):
    assert opcode not in matched, ('unverified guest evidence claimed', opcode)
counts, _ = module.source_counts()
assert counts['pushj'] > 0 and counts['blt'] > 0
assert sum(counts.values()) > 0
print('AAP kernel static coverage evidence mapping v1: PASS')
