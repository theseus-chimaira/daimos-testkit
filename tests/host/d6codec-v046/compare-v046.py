#!/usr/bin/env python3
"""Reproduce v045 grouped two-word matching across complete DXR payloads."""
import pathlib,sys
from importlib.machinery import SourceFileLoader
m=SourceFileLoader('v039','tests/host/d6codec-v039/compare-v039.py').load_module()
v=SourceFileLoader('v040','tests/host/d6codec-v040/compare-v040.py').load_module()
a=SourceFileLoader('v044','tests/host/d6codec-v044/ablate-v044.py').load_module()

def native_policy(src):
 tokens=[];p=0;n=len(src)
 while p<n:
  lim=min(127,n-p)
  if src[p]==0:
   z=1
   while z<lim and src[p+z]==0:z+=1
   tokens.append((1,1,z,0));p+=z;continue
  best=0;dist=0
  for d in range(min(128,p),0,-1):
   if src[p]!=src[p-d]:continue
   q=1
   while q<lim and src[p+q]==src[p+q-d]:q+=1
   if q>best:best=q;dist=d
   if q==127:break
  if best>=2:tokens.append((1,0,best,dist));p+=best
  else:tokens.append((0,src[p]));p+=1
 return v.pack(tokens)

if __name__=='__main__':
 totals=[0,0,0,0]
 for line in m.MANIFEST.read_text().splitlines()[1:]:
  cols=line.split('\t');src=m.load(pathlib.Path(cols[0]));native=native_policy(src)
  even,_=a.encode(src,2,'even',False)
  assert m.decode(native,len(src))==list(src)
  assert a.decode_all(even,len(src))==list(src)
  x=(len(src),len(native),len(even),len(native)-len(even))
  totals=[u+w for u,w in zip(totals,x)]
  print(pathlib.Path(cols[0]).name,*x,sep='\t')
 print('TOTAL raw=%d native_v045_policy=%d v006_evenhalf=%d gap=%d'%tuple(totals),file=sys.stderr)
