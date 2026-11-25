"""Generate sealed TSFS descriptors and source-linked native test cases."""
from pathlib import Path
import sys
repo, work = map(Path, sys.argv[1:])
mask = (1 << 36) - 1
identity = [0o1234567, 0o7654321, 7, 3, 0o123456701234]
records = {}
cases = []
def descriptor(count, member, change=None, unsealed=False):
    d = [0] * 128
    d[:12] = [0o646346630000, (1 << 18) | 1, 0,
              *identity[:3], (count << 18) | member, 0o1102,
              identity[3], 1, identity[4], 0]
    if change is not None:
        d[change] ^= 1
    total = 0
    for i, w in enumerate(d):
        total = (((total << 1) | (total >> 35)) & mask) ^ (w if i != 11 else 0)
        total = (total + 1) & mask
    d[11] = total ^ int(unsealed)
    key = tuple(d)
    if key not in records:
        records[key] = 'record_v1928_%d' % len(records)
    return records[key]

def add(units, fault=None, mapping=None, expected=0):
    ptrs = ['0'] * 16
    for ordinal, unit in enumerate(units):
        for copy in range(2):
            ptrs[2*unit+copy] = descriptor(len(units), ordinal)
    if fault:
        unit, copy, action = fault
        if action == 'error':
            ptrs[2*unit+copy] = '0'
        elif action == 'false-success':
            ptrs[2*unit+copy] = '1'
        elif action == 'bad-seal':
            ptrs[2*unit+copy] = descriptor(len(units), units.index(unit), unsealed=True)
        elif action == 'both-error':
            ptrs[2*unit:2*unit+2] = ['0','0']
        elif action == 'both-false':
            ptrs[2*unit:2*unit+2] = ['1','1']
        else:
            ptrs[2*unit+copy] = descriptor(len(units), units.index(unit), change=action)
    mapword = sum(1 << (24+u) for u in units) | sum(u << (3*i) for i,u in enumerate(units))
    if mapping is not None:
        mapword = mapping
    cases.append([mapword, expected, *ptrs])

# Table-directory ordinal zero is valid in each member-count fixture.
add([0,5])
for field in (0,1,2,3,4,5,6,7,8,9,10,12):
    add([0,5], (5,1,field), expected=-1)
    add([0,5])  # exact original retry
for action in ('error','false-success','bad-seal'):
    add([0,5], (5,0,action))
for action in ('both-error','both-false'):
    add([0,5], (0,0,action), expected=-1)
    add([0,5])
add([0,5], mapping=(0o41<<24), expected=-1) # duplicate unit zero
add([0,5], mapping=(0o41<<24)|0o150, expected=-1) # trailing selector
add([0,5], mapping=0, expected=-1)
add([4,1,6,2,5,3,0,7])
add([0])
add([0], (0,0,'both-false'), expected=-1)
add([0])
add([0,5])

def word(v):
    return str(v) if isinstance(v,str) else ('-1' if v == -1 else '0%012o' % v)
out=['.data','.globl case_count_v1928','.equ case_count_v1928,%d' % len(cases),'.globl cases_v1928','cases_v1928:']
for c in cases:
    out.extend(' .word '+word(v) for v in c)
for d,label in records.items():
    out.append(label+':')
    out.extend(' .word '+word(v) for v in d)
(work/'cases.s').write_text('\n'.join(out)+'\n')
s=(repo/'system/kernel/fs/tsfs_runtime.s').read_text()
a=s.index('tsfs_identity_v1928: .block 5')
b=s.index('; int tsfs_root_owns_dtc_unit_v1516',a)
m=s.index('tsfs_mount_set:')
n=s.index('; int tsfs_lookup',m)
cache=(repo/'system/kernel/storage/bcache_pdp6.s').read_text()
c=cache.index('bcache_invalidate_all:')
d=cache.index('; void bcache_workspace_invalidate',c)
base='.bss\n.globl tsfs_identity_v1928\n'+s[a:b]+'.text\n.globl tsfs_mount_set\n.globl bcache_invalidate_all\n'+s[m:n]+cache[c:d]
(work/'base.s').write_text(base)
for name,old,new in [
    ('unsafe-set-id','        came    4,tsfs_identity_v1928\n        jrst    tsfs_media_conflict_v1928\n',''),
    ('unsafe-generation','        came    4,tsfs_identity_v1928+2\n        jrst    tsfs_media_conflict_v1928\n',''),
    ('unsafe-directory','        came    4,tsfs_identity_v1928+4\n        jrst    tsfs_media_conflict_v1928\n',''),
    ('unsafe-copy-conflict','        jumpg   1,tsfs_media_refuse_v1928\n        and     1,015','        and     1,015'),
    ('unsafe-suspect','        iorm    4,(013)\n',''),
    ('unsafe-cache','        pushj   17,bcache_invalidate_all\n',''),
    ('unsafe-scratch','        setzm   fs_block_workspace\n        move    4,[fs_block_workspace,,fs_block_workspace+1]\n        blt     4,fs_block_workspace+0177\n',''),
]:
    assert base.count(old)==1,name
    (work/(name+'.s')).write_text(base.replace(old,new,1))
print('%d descriptor/map cases, %d distinct descriptor blocks' % (len(cases),len(records)))
