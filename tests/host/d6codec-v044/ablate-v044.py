#!/usr/bin/env python3
"""Ablate v006 token-selection decisions; always pack the paired v006 stream."""
import pathlib,sys
sys.path.insert(0,'tests/host/d6codec-v039')
from importlib.machinery import SourceFileLoader
m=SourceFileLoader('v039','tests/host/d6codec-v039/compare-v039.py').load_module()
sys.path.insert(0,'tests/host/d6codec-v040')
v=SourceFileLoader('v040','tests/host/d6codec-v040/compare-v040.py').load_module()
MASK=(1<<18)-1

def half(a,h):return ((a[h//2]>>(0 if h&1 else 18))&MASK)

def decode_all(x,n):
 out=[];ip=0
 while len(out)<n:
  ctrl=x[ip];ip+=1;ct=ctrl>>30;flags=ctrl&((1<<30)-1)
  nm=sum(bool(flags&(1<<(29-i))) for i in range(ct));d=x[ip:ip+(nm+1)//2];ip+=(nm+1)//2;di=0
  for i in range(ct):
   if not flags&(1<<(29-i)):out.append(x[ip]);ip+=1;continue
   desc=(d[di//2]>>(18 if not di%2 else 0))&0x3ffff;di+=1
   kind=desc>>16;l=(desc>>9)&127;dist=desc&511
   if kind==1:assert not dist;out.extend([0]*l)
   elif kind==0:
    for _ in range(l):out.append(out[-dist])
   else:
    assert kind==2
    if not dist%2:
     for _ in range(l):out.append(out[-dist//2])
    else:
     for j in range(l*2):
      h=2*len(out)-(1 if j%2 else 0)
      val=half(out,h-dist)
      if j%2==0:out.append(val<<18)
      else:out[-1]|=val
 assert len(out)==n and ip==len(x)
 return out

def encode(a,zero_threshold=1,half_mode='off',word_near=False):
 p=0;n=len(a);tokens=[];counts=[0,0,0,0]
 while p<n:
  lim=min(127,n-p);best=0;dist=0;kind=0
  z=0
  while z<lim and a[p+z]==0:z+=1
  if z>=zero_threshold and z>=2:best=z;kind=1
  for d in (range(1,min(128,p)+1) if word_near else range(min(128,p),0,-1)):
   q=0
   while q<lim and a[p+q]==a[p+q-d]:q+=1
   if q>=3 and q>best:best=q;dist=d;kind=0
  if half_mode!='off':
   for hd in range(1, min(256,p*2)+1):
    if half_mode=='even' and hd&1:continue
    if half(a,p*2)!=half(a,p*2-hd):continue
    q=1
    while q<lim*2 and half(a,p*2+q)==half(a,p*2+q-hd):q+=1
    q=q//2
    if q>=2 and q>best:best=q;dist=hd;kind=2
  if best:
   tokens.append((1,kind,best,dist));counts[kind]+=1;p+=best
  else:tokens.append((0,a[p]));counts[3]+=1;p+=1
 return v.pack(tokens),counts

if __name__=='__main__':
 modes=[('zero1-wordonly',1,'off',False),('zero2-wordonly',2,'off',False),('zero2-evenhalf',2,'even',False),('zero2-allhalf',2,'all',False),('zero2-nearword',2,'off',True)]
 totals={key:[0,0,0,0,0] for key,*_ in modes}
 for line in m.MANIFEST.read_text().splitlines()[1:]:
  x=line.split('\t');src=m.load(pathlib.Path(x[0]))
  for key,th,mode,near in modes:
   out,ct=encode(src,th,mode,near)
   assert decode_all(out,len(src))==list(src),(key,x[0])
   t=totals[key];t[0]+=len(out)
   for i in range(4):t[i+1]+=ct[i]
 for key,*_ in modes:
  z=totals[key];print('%s\t%d\t%d\t%d\t%d\t%d'%(key,*z))
