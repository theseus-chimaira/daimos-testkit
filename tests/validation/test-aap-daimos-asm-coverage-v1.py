#!/usr/bin/env python3
"""Exercise broad source inventory without generated build double-counting."""
import importlib.util
from pathlib import Path
import tempfile,os
spec=importlib.util.spec_from_file_location('inventory',Path(__file__).resolve().parents[2]/'tools/aap-daimos-asm-coverage-v1.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
with tempfile.TemporaryDirectory(prefix='aap-all-asm-v1.',dir=os.environ.get('TMPDIR',str(Path.home()/'tmp'))) as d:
    root=Path(d)
    for name in ('system/kernel/a.s','userland/editor/b.S','build/c.s'):
        path=root/name;path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text('entry: movei 1,2\n pushj 17,routine ; comment\n.word 123\n')
    files,counts,unknown,special=mod.inventory(root)
    assert files=={'system':1,'userland':1,'build':1}
    assert all(counts[k]['movei']==1 and counts[k]['pushj']==1 for k in files)
    assert 'word' not in counts['system']
    assert not special
    assert {'setzm', 'hrli', 'sojg', 'idivi'}.issubset(mod.ADDITIONAL_OPCODES)
print('AAP all-DAIMOS assembler inventory v1: PASS')
