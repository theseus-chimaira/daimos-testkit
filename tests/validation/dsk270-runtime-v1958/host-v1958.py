#!/usr/bin/env python3
"""Interrupt actual partial native DCT transfers; attach a distinct disk."""
import hashlib
import os
import runpy
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
V = runpy.run_path(str(HERE.parent/'disk-swap-loss-v1956/host-v1956.py'))
H = V['H']
MASK = (1 << 18) - 1
work = Path(sys.argv[5]).resolve().parent
media = {}
operation = V['operation']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fault_boundary(coremap, examine, read, send, wait, output):
    addr = H['source_symbol'](coremap, 'storage_iowd')
    first = read(addr)
    already = (first >> 18) - ((-128) & MASK)
    assert 0 <= already <= 1, oct(first)
    # Clear command-issue breakpoint. Watch the real IOWD write of each
    # BLKI/BLKO; it is the CPU's native transfer progress, not a timer.
    examine('nobreak all\n')
    examine('break -W %o\n'%addr)
    for i in range(1,9-already):
        start = len(output)
        send(b'go\n')
        wait('Breakpoint, PC:',start,30)
        wait('sim> ',start,20)
        cur = read(addr)
        assert cur >> 18 == ((-128+already+i)&MASK), (i,oct(cur))
        assert cur & MASK == ((first+i)&MASK)
    examine('nobreak all\n')
    print('native DCT %s: IOWD %012o -> %012o, exactly 8/128 words' %
          (operation,first,cur),flush=True)


def after_detach(coremap, examine, read, unit, raw):
    assert unit==0
    original = work/('dsk%d.dsk'%unit)
    replacement = work/'replacement-v1958.dsk'
    # Distinct backing-sector contents, same geometry, no guest access.
    # Only the selected disk's first swap sector is compared against the
    # original source image for WRITE. READ has a committed backing run.
    cyl,sec = (raw>>6)&0o1777,raw&0o77
    assert sec<44
    off=(44*cyl+sec)*128*8
    data=original.read_bytes()
    assert off+1024<=len(data)
    if operation=='write':
        source=Path(sys.argv[7])/'boot.ini'
        line,=[l for l in source.read_text().splitlines()
                if l.startswith('attach -q dsk0 ')]
        with Path(line.split()[3]).open('rb') as f:
            f.seek(off)
            assert f.read(1024)==data[off:off+1024]
    # Different data in the same addressed sector (36-bit words).
    new=bytearray(data)
    for i in range(128):
        pos=off+8*i
        word=int.from_bytes(new[pos:pos+8],'little')
        new[pos:pos+8]=(word ^ 0o123456701234).to_bytes(8,'little')
    replacement.write_bytes(new)
    media.update({original:digest(original),replacement:digest(replacement)})
    examine('attach -q dsk0 %s\n'%replacement)
    print('selected replacement attached before PI5; old and new sector %06o differ'%raw,flush=True)


def after_release(*args):
    return V['after_release'](*args,fault_boundary=fault_boundary,
                              after_detach=after_detach)


if __name__=='__main__':
    H['run'](sys.argv,extra_snapshot=V['V']['extra_snapshot'],
             before_release=V['before_release'],after_release=after_release)
    assert len(media)==2 and all(digest(p)==h for p,h in media.items())
    print('PASS original and replacement disk SHA256 unchanged after detach',flush=True)
