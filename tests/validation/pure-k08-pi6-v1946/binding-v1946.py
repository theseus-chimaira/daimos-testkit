"""Bind physical PI6 return PCs to actual installed source-linked modules."""
import hashlib
import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
prior = runpy.run_path(str(HERE.parent/'pure-k07-full-v1941/replay-v1941.py'))
symbols = prior['symbols']
MASK = 0o777777


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(build, work):
    # The v1945 reduced fixture retained the packaged KINIT but not
    # separate DTFS/TSFS link artifacts. Require its identical original
    # source build, not an unrelated newer provider map.
    original = Path(os.environ['V1946_PROVIDER_BUILD']).resolve()
    for name in ('kcore.dxr','kinit.lowmem.words','pure-mres-v1612.dxr'):
        assert digest(original/name)==digest(build/name), name
    names=('dtfs-mres.map','dtfs-mres.dxr','tape-mres.map','tape-mres.dxr')
    for name in names:
        shutil.copyfile(original/name,work/name)
    (work/'provider.sha256').write_text(''.join(digest(work/n)+'  '+n+'\n'
                                                for n in names))
    (work/'provider-origin.txt').write_text(str(original)+'\n'+
                 digest(original/'kinit.lowmem.words')+'\n')


def read(build,work,prefix):
    hashes=dict((name,d) for d,name in (line.split() for line in
                (work/'provider.sha256').read_text().splitlines()))
    assert set(hashes)=={'dtfs-mres.map','dtfs-mres.dxr','tape-mres.map','tape-mres.dxr'}
    for name,d in hashes.items():
        assert digest(work/name)==d
    origin,packaged=(work/'provider-origin.txt').read_text().splitlines()
    assert digest(build/'kinit.lowmem.words')==packaged
    def image(path):
        h=subprocess.check_output([str(prefix/'bin/dxrcheck'),str(path)],
                                  text=True)
        match=re.search(r'image=([0-7]+) bss=([0-7]+)',h)
        assert match
        return int(match.group(1),8)
    return (symbols(work/'dtfs-mres.map'),image(work/'dtfs-mres.dxr'),
            image(build/'pure-mres-v1612.dxr'),
            symbols(work/'tape-mres.map'),image(work/'tape-mres.dxr'))


def classify(pc,d,s,base,provider):
    local,provider_words,pure_words,tape,tape_words=provider
    dj,tj=(d[s[name]] for name in ('fs_dtfs_service_jump','fs_tsfs_service_jump'))
    assert dj>>18==tj>>18==0o254000
    dt=(dj&MASK)-local['dtfs_mres_dispatch']
    ts=(tj&MASK)-local['tsfs_mres_dispatch']
    assert dt==ts and dt>0, 'provider trampolines disagree'
    assert dt>=s['__kcore_low_end']
    assert dt+provider_words<=base or base+pure_words<=dt
    # Device I/O runs on the same slot-0 continuation. The actual
    # interrupt can be in the tape driver, not only the loader or VFS.
    bindings=(('sys_dtc_read_block_jump','dtc_read_block',0o260740),
              ('storage_pi_tape_jump','tape_pi_handler',0o254000),
              ('storage_dct_tape_jump','tape_dct_handler',0o254000),
              ('storage_clock_tape_jump','tape_watchdog_tick_v1089',0o260740))
    starts=[]
    for jump,entry,opcode in bindings:
        v=d[s[jump]]
        assert v>>18==opcode, jump
        starts.append((v&MASK)-tape[entry])
    assert len(set(starts))==1, 'tape driver jumps disagree'
    tb=starts[0]
    assert tb>=s['__kcore_low_end']
    ranges=sorted(((tb,tb+tape_words),(dt,dt+provider_words),(base,base+pure_words)))
    assert all(a[1]<=b[0] for a,b in zip(ranges,ranges[1:]))
    assert not s['proc_idle_loop']<=pc<s['proc_finish_backoff_advance_v885']
    if base<=pc<base+pure_words:
        return 'PURE'
    if dt<=pc<dt+provider_words:
        return 'DTFS/TSFS'
    if tb<=pc<tb+tape_words:
        return 'TAPE'
    if 0o60<=pc<s['__kcore_low_init_end']:
        return 'KCORE'
    arena_count=d[s['mm_arena_count']]
    assert 0<arena_count<=3
    first=min(d[s['mm_arenas']+i]&MASK for i in range(arena_count))
    if s['__kcore_low_end']<=pc<first:
        return 'other reserved executive'
    raise AssertionError('PI6 saved PC outside reserved executive memory')
