#!/usr/bin/env python3
"""Fail-closed root snapshot and linked map integrity tests."""
import importlib.util
from pathlib import Path
import tempfile

root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('snapshot',root/'tools/check-pdp6-root-snapshot-v1.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as d:
    log=Path(d)/'boot.log';mapping=Path(d)/'kinit.map'
    mapping.write_text('d6fs_active_reader 023316\nvfs_namespace_root 023366\nvfs_mount_root 023312\nkinit_boot_handoff 112634\n')
    good='?RT\nHALT instruction\n23312: 000000000000\n23313: 000000000000\n23314: 000000000000\n23315: 000000000000\n23316: 000000040557\n23366: 000000000000\n112634: 000000200000\n112635: 400000600000\n'
    log.write_text(good)
    assert 'namespace root absent' in module.classify(log,mapping)
    for bad in (good.replace('23366: 000000000000','23366: 000000000001'),
                good.replace('23316: 000000040557','23316: 000000000000'),
                good.replace('112635: 400000600000',''),
                good.replace('23313: 000000000000','23313: 000000000001'),
                good.replace('?RT','?XX')):
        log.write_text(bad)
        try: module.classify(log,mapping)
        except ValueError: pass
        else: raise AssertionError('unsubstantiated root state accepted')
print('PDP-6 linked KINIT root snapshot v1: PASS')
