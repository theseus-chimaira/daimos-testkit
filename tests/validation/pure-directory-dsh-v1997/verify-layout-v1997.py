#!/usr/bin/env python3
"""Prove equal boot and file payloads in two compact TSFS media layouts."""
from pathlib import Path
import struct
import sys

BLOCK = 128
MASK = (1 << 18) - 1


def words(path):
    data = path.read_bytes()
    assert len(data) == 578 * BLOCK * 8
    a = struct.unpack('<%dI' % (len(data)//4), data)
    assert all(x <= MASK for x in a)
    return [(x << 18) | y for x, y in zip(a[::2], a[1::2])]


def region(images, member, start, count):
    assert 0 <= member < len(images) and 0 <= start < start+count <= 578
    return images[member][start*BLOCK:(start+count)*BLOCK]


def main():
    assert len(sys.argv)==3
    a,b = (Path(x) for x in sys.argv[1:])
    aa,bb = ([words(p.parent/(p.name+'%d.dta'%i)) for i in range(3)]
             for p in (a,b))
    # Member 0 block zero contains in-place Stage1 and boot tail pointer.
    assert aa[0][:BLOCK] == bb[0][:BLOCK]
    t,u = aa[0][3*BLOCK:4*BLOCK],bb[0][3*BLOCK:4*BLOCK]
    assert t[:6]==u[:6]
    assert t[3]>0 and t[4]>0
    # These are compact fixture V1.1 FILE/EXTENT table entries.
    assert t[7]>>18==u[7]>>18==1 and t[12]>>18==u[12]>>18==2
    assert t[7:12]==u[7:12]
    assert t[12:16]==u[12:16]
    f,nf = t[8]&MASK,t[9]>>18
    e,ne = t[13]&MASK,t[14]>>18
    assert nf>0 and ne>0
    assert region(aa,0,f,nf)==region(bb,0,f,nf)
    old,new=region(aa,0,e,ne),region(bb,0,e,ne)
    first=578
    for i in range(t[4]):
        x,y=old[4*i:4*i+4],new[4*i:4*i+4]
        assert x[0]==y[0] and x[2:]==y[2:]
        m,p=x[1]>>18,x[1]&MASK
        n,q=y[1]>>18,y[1]&MASK
        l=x[2]&MASK
        assert m==0 and n==1
        assert region(aa,m,p,l)==region(bb,n,q,l)
        first=min(first,p)
        print('extent %d: member%d/%04o -> member%d/%04o, %d identical sectors' %
              (i,m,p,n,q,l))
    tail=aa[0][3]
    assert 0<tail<first
    assert region(aa,0,tail,first-tail)==region(bb,0,tail,first-tail)
    print('PASS: identical Stage1, boot tail, file table and all stored file extents')


if __name__=='__main__':
    main()
