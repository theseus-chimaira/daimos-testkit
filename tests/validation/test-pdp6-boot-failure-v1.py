#!/usr/bin/env python3
"""Test strict recognition of DAIMOS fatal root diagnostics."""
import importlib.util
from pathlib import Path

path = Path(__file__).resolve().parents[2]/'tools/check-pdp6-boot-failure-v1.py'
spec = importlib.util.spec_from_file_location('boot_failure', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
real = 'DAIMON V0.5\nBSET LOADED\n?RT\nHALT instruction\nPC: 071470\n'
result = module.classify(real)
assert result['status'] == 'fatal-root-boot' and result['pc_octal'] == '071470'
for text in (real.replace('?RT', '?XX'), real.replace('HALT instruction', 'Step expired'),
             real.replace('PC: 071470', ''), real.replace('DAIMON V0.5', '')):
    try:
        module.classify(text)
    except ValueError:
        pass
    else:
        raise AssertionError('invalid root failure evidence accepted')
print('PDP-6 root boot failure classification v1: PASS')
