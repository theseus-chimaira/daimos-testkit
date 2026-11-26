#!/usr/bin/env python3
"""Require exact baseline MM owner/extent restoration, not just total RAM."""
import re
import runpy
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
V = runpy.run_path(str(HERE.parent/'pure-runtime-reclaim-v1673/measure-v1673.py'))
assert len(sys.argv)==4
fixture, coremap, console=map(Path,sys.argv[1:])
text=console.read_text(encoding='ascii')
a,b,c=V['observations'](text,fixture)
count=V['lookup'](coremap,'mm_extent_count')
base=V['lookup'](coremap,'mm_extents')
table=V['lookup'](coremap,'proc_table')
mode=V['lookup'](coremap,'proc_storage_runtime_v29')
record=V['lookup'](coremap,'proc_swap_records')
x,y=a['words'],c['words']
assert x[count]==y[count]==9
assert all(x[base+i]==y[base+i] for i in range(2*x[count]))
assert x[table]==y[table] and x[mode]==y[mode] and x[record]==y[record]
assert x[x[mode]]==y[y[mode]]==0
# Parent's stable u-area pointer and APR must be unchanged. The
# scheduling word may contain a different legitimate wait timestamp.
p=x[table]
assert x[p+3]==y[p+3] and x[p+4]==y[p+4]
assert x[x[record]+1]==y[y[record]+1]
print('PASS exact baseline MM extent/owner table and parent VM restored')
