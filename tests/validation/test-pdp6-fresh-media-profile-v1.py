#!/usr/bin/env python3
"""Reject reused/colliding media and confirm explicit boot PC in bounded script."""
import importlib.util
from pathlib import Path
import tempfile

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('fresh',ROOT/'tools/pdp6-fresh-media-profile-v1.py')
fresh=importlib.util.module_from_spec(spec)
spec.loader.exec_module(fresh)
with tempfile.TemporaryDirectory() as tmp:
    root=Path(tmp)/'production'
    root.mkdir()
    (root/'disk').mkdir()
    (root/'drum').mkdir()
    (root/'disk/dsk0.dsk').write_bytes(b'disk-image')
    (root/'drum/dsk0.dsk').write_bytes(b'drum-image')
    boot=root/'boot.ini'
    boot.write_text('attach -q dsk0 '+str(root/'disk/dsk0.dsk')+'\n'
                    'attach -q dr0 '+str(root/'drum/dsk0.dsk')+'\n'
                    'go 020\n')
    out=Path(tmp)/'profile'
    script,manifest=fresh.prepare(boot,out,100)
    text=script.read_text()
    assert 'deposit PC 020\nstep 100' in text
    assert len(manifest['media'])==2
    assert (out/'media/disk/dsk0.dsk').read_bytes()==b'disk-image'
    assert (out/'media/drum/dsk0.dsk').read_bytes()==b'drum-image'
    try:
        fresh.prepare(boot,out,100)
    except ValueError:
        pass
    else:
        raise AssertionError('reused output incorrectly accepted')
    try:
        fresh.prepare(boot,root,100)
    except ValueError:
        pass
    else:
        raise AssertionError('production output incorrectly accepted')
print('PDP-6 fresh isolated media profile v1: PASS')
