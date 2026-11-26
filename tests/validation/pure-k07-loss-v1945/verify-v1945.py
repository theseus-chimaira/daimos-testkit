#!/usr/bin/env python3
"""Independent offline acceptance of real physical K07 source recovery."""
import argparse
import hashlib
from pathlib import Path
import re
import runpy
import subprocess

HERE = Path(__file__).resolve().parent
old = runpy.run_path(str(HERE.parent / 'pure-k07-full-v1941/verify-v1941.py'))
reel = runpy.run_path(str(HERE.parent / 'pure-k07-race-v1943/check-reel-v1944.py'))
symbols, words, extents = old['symbols'], old['words'], old['extents']
MASK = 0o777777
SUSPECT = 0o200000


def verify(b, w, prefix, trace=None):
    s, m = symbols(b/'kcore.map'), symbols(b/'pure-mres-v1612.map')
    if trace is None:
        trace = (w/'physical.clean').read_text(encoding='ascii')
    for name, directory, required in (
            ('images.sha256',b,{'kcore.dxr','kinit.lowmem.words','pure-mres-v1612.dxr'}),
            ('media.sha256',w/'media',{'dtc3.tap','foreign.tap'})):
        hashes = {}
        for line in (w/name).read_text().splitlines():
            digest, filename = line.split()
            assert filename not in hashes and filename in required
            assert hashlib.sha256((directory/filename).read_bytes()).hexdigest() == digest
            hashes[filename] = digest
        assert set(hashes) == required
    original, foreign = w/'media/dtc3.tap', w/'media/foreign.tap'
    reel['verify'](b/'media/dtc3-home-v22.tap',original,b/'../user/comp-v1638.dxr')
    reel['seal'](foreign)
    oi, fi = reel['read_reel'](original)[1:3], reel['read_reel'](foreign)[1:3]
    assert oi != fi, 'foreign reel has original identity'
    assert 'MEM                                  48 K' in trace
    assert 'PURE                              LOADED' in trace
    assert 'DTFS                              LOADED' in trace
    match = re.search(r'I(a{4,6})x\[BV1945_STAGE_B\n',trace)
    assert match, 'missing actual successful admission/refusal witness'
    children = len(match.group(1))
    assert trace.count('HALT instruction') == 1 and 'HALT instruction, PC: 000000' in trace
    assert 'Goodbye' in trace
    labels = re.findall(r'(?m)^V1945_STAGE_([A-Z0-9_]+)$',trace)
    # EXPECT stops put the guest marker immediately before the monitor
    # label; those two labels need not start a new text line.
    labels = re.findall(r'V1945_STAGE_([A-Z0-9_]+)\n',trace)
    assert labels[:4] == ['B','A','FULL','MISSING'] and labels[-1:] == ['Z']
    assert labels[4:-1] == ['FOREIGN_%d'%i for i in range(len(labels)-5)]
    assert len(labels) >= 6 and len(set(labels)) == len(labels)
    tables, spans, ranges = {}, {}, {}
    last = -1
    for label in labels:
        a, z = 'V1945_STAGE_'+label+'\n', 'V1945_END_'+label+'\n'
        assert trace.count(a)==trace.count(z)==1
        begin, end = trace.index(a), trace.index(z)
        assert last < begin < end
        ranges[label] = (begin,end+len(z))
        last = end
        d = words(trace[begin:end]); tables[label] = d
        spans[label] = extents(d,s)
        assert not d[s['proc_exec_resv_head_v1933']]
    B,A,F,M,Z = (tables[l] for l in ('B','A','FULL','MISSING','Z'))
    foreign_label = labels[-2]; R = tables[foreign_label]
    assert spans['B'] == spans['A']
    assert B[s['proc_current_slot']] == A[s['proc_current_slot']] == Z[s['proc_current_slot']] == 1
    assert F[s['proc_current_slot']] == M[s['proc_current_slot']] == R[s['proc_current_slot']] == 0
    assert F[s['proc_sched_cursor']] == M[s['proc_sched_cursor']] == R[s['proc_sched_cursor']] == 3
    source = [q for q in spans['A'] if q[2]==4 and q[4]==3]
    assert len(source)==1 and source[0][3]==0
    src = source[0]
    assert (src[0],src[1],4,1,3) in spans['FULL']
    dst = [q for q in spans['FULL'] if q[2]==1 and q[4]==3]
    assert len(dst)==1 and dst[0][3]==1
    dst=dst[0]
    assert dst[0]==F[2] and dst[1]-dst[0]==F[4] and dst[0]%0o2000==0
    assert src[1]<=dst[0] or dst[1]<=src[0]
    assert F[1]>>18&15==1 and F[1]>>22
    assert F[4] == 0o6000, 'unexpected accepted secondary child APR capacity'
    skip=((F[1]>>22)+0o20)&~0o177
    assert F[4]-(src[1]-src[0])==skip
    u = F[3]
    assert u and (u,u+0o410,3,0,0o1003) in spans['FULL']
    def field(d, name):
        return d[d[s[name]]+1]
    root=field(B,'vfs_mount_root_base')
    assert root>>24==(5<<6)|2 and B[s['vfs_namespace_root']]>>24==(7<<6)|1
    assert field(B,'dtfs_media_base')==0o100003
    for d in (B,A,F,M,R):
        assert field(d,'vfs_mount_root_base')==root
        assert [field(d,'tsfs_file_shape_base'),field(d,'tsfs_extent_media_base')]==oi
        assert d[d[s['proc_table']]+9]>>18==u
        assert d[d[s['proc_table']]+10]&MASK==0
        assert d[u+0o406]==F[1] and (d[u+0o66]>>28)&7==5
    assert M[u+0o67]==R[u+0o67]==0, 'unretired transaction escrow'
    suffix=tuple(F[i] for i in range(src[0],src[1]))
    for l in ('MISSING',foreign_label):
        d=tables[l]
        assert d[1]==0o777777777774
        assert field(d,'dtfs_media_base')==0o100003|SUSPECT
        assert [q for q in spans[l] if q[2] in (1,4) and q[4]==3]==source
        assert tuple(d[i] for i in range(src[0],src[1]))==suffix
        assert (u,u+0o410,3,0,0o1003) in spans[l]
    # Resolve both original transaction return PCs from the linked code,
    # and check the actually installed FULL opcode independently.
    base=(B[s['proc_swap_service_one']]&MASK)-m['proc_pure_mres_service_v1612']
    assert B[s['proc_swap_service_one']]>>18==0o254000
    assert B[s['proc_swap_reclaim']]==0o254000000000|(base+m['proc_pure_mres_reclaim_v1612'])
    full=base+m['exec_image_full_bounded_v1391']
    dump=subprocess.check_output([str(prefix/'bin/dxrcheck'),'-d',str(b/'pure-mres-v1612.dxr')],text=True)
    code={int(x,8):int(y,8) for x,y in re.findall(r'(?m)^IMAGE\s+([0-7]{6}) ([0-7]{12})$',dump)}
    assert words(trace[ranges['A'][1]:trace.index('V1945_OPCODE\n')])[full]==code[full-base]
    def callret(name):
        hits=[base+i+1 for i,v in code.items() if m['proc_pure_mres_service_v1612']<=i<m['proc_pure_mres_service_v1612']+0o400 and v==0o260740000000|m[name]]
        assert len(hits)==1
        return hits[0]
    pr,fr=callret('proc_pure_restore_v1384'),callret('proc_pure_ram_restore_v1391')
    def before(label):
        i=labels.index(label)
        return trace[ranges[labels[i-1]][1]:ranges[label][0]]
    assert re.search(r'Breakpoint, PC: %06o\b'%full,before('FULL'))
    missing=before('MISSING')
    assert re.search(r'Breakpoint, PC: %06o\b'%fr,missing)
    assert re.search(r'DTC3\s+147KW, not attached',missing)
    foreign_stop=before('FOREIGN_0')
    assert re.search(r'DTC3[^\n]*foreign\.tap',foreign_stop)
    assert re.search(r'Breakpoint, PC: (?:%06o|%06o)\b'%(pr,fr),before(foreign_label))
    recovered=before('Z')
    assert re.search(r'DTC3[^\n]*dtc3\.tap',recovered)
    assert recovered.endswith('Z'), 'missing genuine successful guest Z'
    assert field(Z,'vfs_mount_root_base')==0
    assert not any((q[2] in (1,4) and q[4]>=2) or (q[2]==3 and q[4]>=0o1002) for q in spans['Z'])
    assert Z[s['proc_timer_clock']]>B[s['proc_timer_clock']]
    # The guest emits w only after the original child suffix sentinels
    # pass and Z only after exact PID/status WAITs and final UNMOUNT.
    # Count w solely outside the monitor-owned table intervals.
    guest_parts=[before(l) for l in labels[1:]]
    guest=''.join(re.sub(r'(?m)^.*(?:Breakpoint, PC:|DTC3\s+147KW|V1945_OPCODE|writing buffer to file:).*\n','',x) for x in guest_parts)
    assert len(re.findall(r'w(?=w|\n|Z)',guest))==children, 'child witnesses missing'
    print('PASS v1945: physical missing/foreign identity refusal, exact %d-word RAW suffix, same-volume recovery, %d WAITs' % (len(suffix),children))


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for n in ('build','work','prefix'):
        p.add_argument(n,type=Path)
    a=p.parse_args()
    try:
        verify(a.build,a.work,a.prefix)
    except (AssertionError,KeyError,ValueError,OSError) as exc:
        p.exit(1,'FAIL v1945 physical acceptance: %s\n'%exc)
