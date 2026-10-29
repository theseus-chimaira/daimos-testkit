#!/usr/bin/env python3
"""Generate assembled direct-clock variants without changing production."""
from pathlib import Path
import argparse
import re
import subprocess

p=argparse.ArgumentParser()
p.add_argument('repo',type=Path)
p.add_argument('build',type=Path)
p.add_argument('--assembler',default='das')
a=p.parse_args()
a.build.mkdir(parents=True,exist_ok=True)
files={'memfs_runtime.s':'fs/memfs_runtime.s',
       'd6fs_runtime.s':'fs/d6fs_runtime.s',
       'd6fs_provider_mutation.s':'fs/d6fs_provider_mutation.s',
       'd6fs_provider_namespace_pdp6.s':'fs/d6fs_provider_namespace_pdp6.s'}
total=0
short={'memfs_runtime.s':'mfr','d6fs_runtime.s':'dfr',
       'd6fs_provider_mutation.s':'dfm','d6fs_provider_namespace_pdp6.s':'dfn'}
for name,rel in files.items():
    source=(a.repo/'system/kernel'/rel).read_text()
    occurrences=len(re.findall(r'^\s*pushj\s+17,wall_time36\b',source,re.M))
    assert occurrences>0,name
    index=[0]
    def replace(m):
        n=index[0];index[0]+=1
        return 'clkbind_'+short[name]+str(n)+':\n        pushj   17,wall_time36'
    direct=re.sub(r'^\s*pushj\s+17,wall_time36\b',replace,source,flags=re.M)
    assert index[0]==occurrences
    # The prototype labels all call instructions for later KINIT relocation.
    for i in range(occurrences):
        sym='clkbind_'+short[name]+str(i)
        direct=direct.replace(sym+':', '.globl '+sym+'\n'+sym+':',1)
    for tag,s in [('base',source),('direct',direct)]:
        asm=a.build/(name+'.'+tag+'.s')
        asm.write_text(s)
        subprocess.run([a.assembler,'-F','-C','-O',str(a.build/(name+'.'+tag+'.dobj')),str(asm)],check=True)
    print('%s: %d direct patchable call(s), instruction count unchanged' %(name,occurrences))
    total+=occurrences
assert total==6
print('v701: six cross-MRES call instructions exported; both versions assemble PASS')
