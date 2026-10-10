#!/bin/sh
# Confirm native DLINK $^ preserves the historical object and archive order.
set -eu
kcc=${KCC_REPO:-"$HOME/git/kcc"}
python3 - "$kcc" <<'PY'
from pathlib import Path
import subprocess,sys,re
root=Path(sys.argv[1])
for filename in ('daimos.mk','native.mk'):
    old=subprocess.check_output(['git','-C',str(root),'show','2118967:'+filename],text=True)
    new=(root/filename).read_text()
    if filename=='daimos.mk':
        pattern=r'^B/[^\s:]+\.DXR:'
        starts=[m.start() for m in re.finditer(pattern,new,re.M)]
        for start in starts:
            name=new[start:].split(':',1)[0]
            def extract(s):
                block=re.search(r'^'+re.escape(name)+r':(.*?)(?=^\S|\Z)',s,re.M|re.S)
                assert block,name
                body=block.group(0)
                command=next(x for x in body.splitlines() if '$(NATIVE_DLINK)' in x)
                return body,command
            a,cmd_old=extract(old)
            b,cmd_new=extract(new)
            before=cmd_old.split(' -O $@ ',1)[1].split()
            deps=' '.join(x.split(':',1)[-1] if i==0 else x for i,x in enumerate(b.splitlines()) if i==0 or x.startswith('    ')).replace('\\','').split()
            assert before==deps,(name,before,deps)
            assert cmd_new.endswith(' -O $@ $^'),name
    else:
        for name in ('DRIVER','KCPP','KPARSE','KGEN','KOPT'):
            tag='$(NATIVE_'+name+'_DXR):'
            def get(s):
                pos=s.index(tag)
                body=s[pos:s.index('\n\n',pos)]
                deps=body.splitlines()[0].split(':',1)[1].split()
                order=body.splitlines()[-1].strip()
                return deps,order
            olddeps,oldcmd=get(old)
            deps,cmd=get(new)
            arguments=oldcmd.splitlines()[-1].split()
            assert sorted(deps)==sorted(olddeps)
            assert deps==arguments
            assert cmd=='$^'
print('PASS: 10 DLINK rules preserve ordered inputs')
PY
