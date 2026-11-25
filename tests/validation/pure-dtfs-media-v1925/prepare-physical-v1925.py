"""Use actual formatted RBN0 blocks and the established raw-I/O fixture."""
from pathlib import Path
import sys
repo, kit, work = map(Path, sys.argv[1:])
mask = (1 << 36) - 1

def block(name):
    data = (work / name).read_bytes()[:1024]
    assert len(data) == 1024
    return [(int.from_bytes(data[i:i+4], 'little') << 18) |
            int.from_bytes(data[i+4:i+8], 'little') for i in range(0, 1024, 8)]

clean = block('v2original.tap')
other = block('v2replacement.tap')
v1 = block('v1original.tap')
assert clean[1:3] != other[1:3] and all(clean[1:3]) and all(v1[1:3])
dirty = clean[:]
dirty[4] = 0o552255225522
dirty[5] = (~(dirty[0]^dirty[1]^dirty[2]^dirty[4]^0o246134572610)) & mask
half = clean[:]
half[2] = 0
records = dict(v2_clean=clean, other=other, v1=v1, dirty=dirty,
               zero=[0]*128, half=half)
root = 0o050101000000
v2 = 0o100003
suspect = 0o200000
# physical, admitted ID, media, policy, raw mode, result, after, reads, invalidation
cases = [
    ('v2_clean','v2_clean',v2,1,0,0,v2,1,1),
    ('other','v2_clean',v2,1,0,-1,v2|suspect,1,1),
    ('v1','v1',3,1,0,0,3,1,1),
    ('other','v1',3,1,0,-1,3|suspect,1,1),
    ('dirty','v2_clean',v2|0o40000,0,0,0,v2|0o40000,1,1),
    ('dirty','v2_clean',v2|0o40000,1,0,-1,v2|0o40000|suspect,1,1),
    ('dirty','v2_clean',v2,1,0,-1,v2|suspect,1,1),
    ('v2_clean','v2_clean',v2,1,1,-1,v2|suspect,1,1),
    ('v2_clean','v2_clean',v2,1,2,-1,v2|suspect,1,1),
    ('v2_clean','v2_clean',v2,1,3,-1,v2|suspect,1,1),
    ('v2_clean','v2_clean',v2,1,4,-1,v2|suspect|0o400000,1,1),
    ('v2_clean','v2_clean',v2,1,5,-1,v2|suspect,1,1),
    ('v2_clean','v2_clean',v2,1,6,-1,v2|suspect,1,1),
    ('v2_clean','v2_clean',v2|0o400000,1,0,-1,v2|0o400000,0,0),
    ('v2_clean','v2_clean',v2|0o20000,1,0,-1,v2|0o20000,0,0),
    ('zero','zero',3,1,0,0,3,0,0),
    ('zero','zero',3|suspect,1,0,-1,3|suspect,0,0),
    ('v2_clean','zero',v2,1,0,-1,v2,0,0),
    ('v2_clean','half',v2,1,0,-1,v2,0,0),
]
def num(n):
    return '-1' if n == -1 else '0%012o' % n
lines = ['.data\n']
for name, words in records.items():
    label = 'record_%s_v1556' % name
    lines.append('.globl %s\n%s:\n' % (label, label))
    lines.extend(' .word %s\n' % num(w) for w in words)
lines.append('.globl case_table_v1556\n.globl case_count_v1556\n.equ case_count_v1556,%d\ncase_table_v1556:\n' % len(cases))
for phys, saved, media, policy, mode, rc, after, reads, inv in cases:
    vals = ('record_%s_v1556'%phys, 'record_%s_v1556'%saved,
            *(num(v) for v in (media, root, policy, mode, rc, after, reads, inv)))
    lines.extend(' .word %s\n' % v for v in vals)
(work/'records.s').write_text(''.join(lines))
fixture=(kit/'tests/validation/daimos-dtfs-v2-revalidate-v1556.s').read_text()
fixture=fixture.replace('        movei   1,1                     ; public slot ID, not physical unit\n        pushj   17,dtfs_identity_revalidate_v1522',
    '        move    1,[050102012345]\n        pushj   17,dtfs_pure_media_v1925')
fixture=fixture.replace('        movem   1,bcache_workspace_tag\n',
    '        movem   1,bcache_workspace_tag\n        movem   1,extra_tag_v1925\n        movem   1,dtfs_cache_mount\n',1)
fixture=fixture.replace('        camn    1,[-1]\n        jrst    case_done_v1556',
    '        came    1,[-1]\n        jrst    case_bad_v1556\n        skipn   dtfs_cache_mount\n        jrst    case_cache_v1925\n        jrst    case_bad_v1556\ncase_cache_v1925:\n        move    1,extra_tag_v1925\n        camn    1,[-1]\n        jrst    case_done_v1556',1)
fixture=fixture.replace('case_no_invalidate_v1556:\n        caie    1,04444\n        jrst    case_bad_v1556',
    'case_no_invalidate_v1556:\n        caie    1,04444\n        jrst    case_bad_v1556\n        move    1,extra_tag_v1925\n        caie    1,04444\n        jrst    case_bad_v1556\n        move    1,dtfs_cache_mount\n        caie    1,04444\n        jrst    case_bad_v1556')
fixture=fixture.replace('bcache_workspace_tag: .word 0',
    'bcache_workspace_tag: .word 0\n.globl dtfs_cache_mount\ndtfs_cache_mount: .word 0\n.globl bcache_state\nbcache_state: .word extra_tag_v1925\nextra_tag_v1925: .word 0')
assert 'pushj   17,dtfs_pure_media_v1925' in fixture
(work/'fixture.s').write_text(fixture)
s=(repo/'system/kernel/fs/dtfs_runtime.s').read_text()
parser=s[s.index('dtfs_identity_validate_v1522:'):s.index('dtfs_lookup:\n',s.index('dtfs_identity_validate_v1522:'))]
guard=s[s.index('dtfs_pure_media_v1925:'):s.index('\n\n.if DTFS_ENABLE_FOREIGN\n; Compact directory enumeration.',s.index('dtfs_pure_media_v1925:'))]
b=(repo/'system/kernel/storage/bcache_pdp6.s').read_text()
cache=b[b.index('bcache_invalidate_all:'):b.index('\n        .bss',b.index('bcache_invalidate_all:'))]
source='.text\n.globl dtfs_pure_media_v1925\n.globl dtfs_identity_revalidate_v1522\n.globl bcache_invalidate_all\n.globl bcache_workspace_invalidate\n'+parser+guard+cache
(work/'baseline.s').write_text(source)
for name,old,new in [('skip-proof','        iorm    3,(2)\n        setzm   dtfs_cache_mount','        setzm   dtfs_cache_mount'),('skip-cache','        pushj   17,bcache_invalidate_all ; no stale directory/payload reuse','        move    4,4')]:
    assert source.count(old)==1
    (work/(name+'.s')).write_text(source.replace(old,new,1))
print('%d physical leaf cases, two unsafe variants' % len(cases))
