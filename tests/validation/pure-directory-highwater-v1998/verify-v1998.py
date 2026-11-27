#!/usr/bin/env python3
"""Replay MM writes; count stable ownership, not partial table shifts."""
import json
import hashlib
from pathlib import Path
import re
import sys

MASK=0o777777
EVENT=re.compile(r'(?m)^Breakpoint, PC: ([0-7]+)[^\n]*\n(?:sim> )?([0-7]+):[ \t]+([0-7]{12})[ \t]*$')


def labels(path):
    return {n:int(v,8) for n,v in re.findall(r'(?m)^(\w+)\s+([0-7]+)$',path.read_text())}


def replay(w, start, trace, snapshots):
    s,m,base=start['symbols'],start['mres'],start['base']
    sh={int(a):v for a,v in start['words'].items()}
    e,c=s['mm_extents'],s['mm_extent_count']
    expected=set(range(e,e+64))|set(range(s['mm_arenas'],s['mm_arenas']+3))|{s[n] for n in ('mm_extent_count','mm_extent_capacity','mm_core_words','mm_arena_count')}
    assert set(sh)==expected and len(expected)==71
    assert {int(x,8) for x in re.findall(r'(?m)^SET BREAK -W ([0-7]+);',trace)}==expected
    assert sh[s['mm_core_words']]==49152 and sh[s['mm_extent_capacity']]==32
    assert sh[s['mm_arena_count']]==1
    a=sh[s['mm_arenas']]&MASK
    z=a+(sh[s['mm_arenas']]>>18)
    assert 0<a<z<=49152
    # Each PC is the NEXT instruction after the actual physical write.
    mm,vm,commit,finish=(labels(w/(n+'.labels')) for n in ('mm','vm','commit','finish'))
    mb=s['mm_extent_insert']-mm['mm_extent_insert']
    vb=s['vm_space_brk_current']-vm['vm_space_brk_current']
    cb=base+m['mm_pure_bitmap_place_v1985']-commit['mm_pure_bitmap_place_v1985']
    fb=base+m['mm_pure_bitmap_finish_v1664']-finish['mm_pure_bitmap_finish_v1664']
    pcs={}
    def bind(b,l,n,offsets,kind):
        for off in offsets:
            pc=b+l[n]+off
            assert pc not in pcs
            pcs[pc]=kind
    bind(mb,mm,'mm_delete_loop',(5,6),'shift')
    bind(mb,mm,'mm_extent_insert_shift',(5,6),'shift')
    bind(mb,mm,'mm_extent_insert_copy',(5,6),'shift')
    bind(mb,mm,'mm_delete_done',(1,),'delete')
    bind(mb,mm,'mm_extent_insert_copy',(7,),'insert')
    bind(mb,mm,'mm_pin_add_ok',(2,),'pin')
    bind(mb,mm,'mm_pin_sub',(2,),'unpin')
    bind(vb,vm,'vm_brk_rebase_extent',(4,),'brk')
    bind(cb,commit,'mbc_place_shift_one_v1985',(6,7),'shift')
    bind(cb,commit,'mbc_place_store_v1985',(5,),'drop_span')
    bind(cb,commit,'mbc_place_store_v1985',(6,),'drop_commit')
    bind(fb,finish,'mbf_delete_v1664',(5,6),'shift')
    bind(fb,finish,'mbf_delete_done_v1664',(1,),'finish')
    bind(fb,finish,'mbf_delete_done_v1664',(8,),'unpin')
    def state(i,kind):
        n=sh[c]
        assert 0<n<=32
        extents=[]
        cursor=a
        largest=0
        for k in range(n):
            span,meta=sh[e+2*k],sh[e+2*k+1]
            b,sz=span&MASK,span>>18
            typ,pin,owner=(meta>>18)&7,(meta>>21)&255,meta&MASK
            assert cursor<=b<b+sz<=z and typ in (1,2,3,4)
            largest=max(largest,b-cursor)
            cursor=b+sz
            extents.append([b,sz,typ,pin,owner])
        largest=max(largest,z-cursor)
        allocated=sum(x[1] for x in extents)
        return dict(event=i,kind=kind,count=n,free=z-a-allocated,occupied=49152-(z-a)+allocated,largest=largest,extents=extents)
    def check_checkpoint(label):
        snap=snapshots[label]
        assert sh[c]==snap['meta']['mm_extent_count']
        assert [sh[e+i] for i in range(2*sh[c])]==snap['extents']
    check_checkpoint('initial')
    stable=[state(-1,'initial')]
    matches=list(EVENT.finditer(trace))
    assert trace.count('Breakpoint, PC:')==len(matches)>0
    assert trace.count('K15HELD')==trace.count('K15REAPED')==trace.count('K15DONE')==trace.count('HALT instruction')==1
    held=trace.index('K15HELD')
    restored=trace.index('KEEP=DAIMOS-K15-STATE',trace.index('K15REAPED'))
    assert held<restored<trace.index('K15DONE')<trace.index('HALT instruction')
    checkpoints=[('held',held),('restored',restored)]
    pending=False
    drops=[]
    for i,match in enumerate(matches):
        while checkpoints and match.start()>checkpoints[0][1]:
            assert not pending
            check_checkpoint(checkpoints.pop(0)[0])
        pc,addr,value=(int(v,8) for v in match.groups())
        assert pc in pcs, 'unexpected writer %06o'%pc
        kind=pcs[pc]
        assert addr==c if kind in ('insert','delete','finish') else e<=addr<e+64
        old=sh[addr]
        sh[addr]=value
        if kind in ('shift','drop_span'):
            pending=True
            continue
        if kind in ('insert','delete','finish'):
            assert value-old==(1 if kind=='insert' else -1)
        if kind in ('pin','unpin'):
            assert not pending and (addr-e)%2 and value-old==((1 if kind=='pin' else -1)<<21)
        if kind=='brk':
            assert not pending and not (addr-e)%2 and (value>>18)-(old>>18)==1024
        if kind=='drop_commit':
            assert pending and (addr-e)%2
        before=stable[-1]
        after=state(i,kind)
        if kind=='drop_commit':
            old_owner=[x for x in before['extents'] if x[4]==2 and x[2]==1]
            new_owner=[x for x in after['extents'] if x[4]==2 and x[2]==4]
            assert len(old_owner)==len(new_owner)==1 and old_owner[0][3]==1
            old_base,old_size=old_owner[0][:2]; new_base,new_size=new_owner[0][:2]
            assert new_size==242 and old_size==16384 and new_owner[0][3]==0
            assert old_base+old_size<=new_base or new_base+new_size<=old_base
            assert all(new_base+new_size<=x[0] or x[0]+x[1]<=new_base for x in before['extents'])
            drops.append(dict(event=i,copy_upper_bound=before['occupied']+new_size,
                              before=before['occupied'],after=after['occupied']))
        stable.append(after)
        pending=False
    assert not pending and not checkpoints
    assert len(drops)==1
    pairs=[x for x in stable if sorted((r[1],r[2]) for r in x['extents'] if r[4]==2 and r[2] in (1,4))==[(242,4),(16384,1)]]
    assert pairs and any(all(r[3]==1 for r in x['extents'] if r[4]==2 and r[2] in (1,4)) for x in pairs)
    peak=max(stable,key=lambda x:x['occupied'])
    assert peak in pairs and any(r[1]==256 and r[2]==3 and r[4]==9 for r in peak['extents'])
    assert stable[-1]['count']==8 and not any(r[2] in (1,4) and r[4]!=1 for r in stable[-1]['extents'])
    return dict(writes=len(matches),stable_samples=len(stable),peak=peak,
                drop=drops[0],pair_peak=max(x['occupied'] for x in pairs),
                max_extents=max(x['count'] for x in stable),
                initial=stable[0],final=stable[-1],samples=stable)


def main():
    w=Path(sys.argv[1])
    start=json.loads((w/'start-v1998.json').read_text())
    trace=(w/'console-v1426.log').read_text().replace('\r','')
    snapshots={n:json.loads((w/(n+'.json')).read_text()) for n in ('initial','held','restored')}
    for p,h in json.loads((w/'hashes-v1998.json').read_text()).items():
        assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==h
    result=replay(w,start,trace,snapshots)
    (w/'highwater-v1998.json').write_text(json.dumps(result,indent=2)+'\n')
    print('PASS %d writes, %d stable samples, peak %d, free %d, max MM %d' %
          (result['writes'],result['stable_samples'],result['peak']['occupied'],result['peak']['free'],result['max_extents']))
    print('DROP',result['drop'])
    print('FULL pair peak',result['pair_peak'],'final free',result['final']['free'])

if __name__=='__main__': main()
