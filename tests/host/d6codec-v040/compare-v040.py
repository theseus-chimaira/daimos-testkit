#!/usr/bin/env python3
"""Compare v039 native token policy with grouping; then aligned-halfword options."""
import pathlib,sys
sys.path.insert(0,'tests/host/d6codec-v039')
from importlib.machinery import SourceFileLoader
m=SourceFileLoader('v039','tests/host/d6codec-v039/compare-v039.py').load_module()

def tokenize(src,half_mode=False):
 p=0;n=len(src);tokens=[]
 while p<n:
  lim=min(127,n-p);z=0
  while z<lim and src[p+z]==0:z+=1
  if z:
   tokens.append((1,1,z,0));p+=z;continue
  best=0;distance=0;kind=0
  for d in range(min(128,p),0,-1):
   if src[p]!=src[p-d]:continue
   q=1
   while q<lim and src[p+q]==src[p+q-d]:q+=1
   if q>=3 and q>best:best=q;distance=d;kind=0
   if q==127:break
  if half_mode:
   # An even halfword-distance copy is word-aligned, so its payload is
   # identical to a word-distance reference. It cannot add a new match.
   pass
  if best>=3:tokens.append((1,kind,best,distance));p+=best
  else:tokens.append((0,src[p]));p+=1
 return tokens

def pack(tokens):
 out=[]
 for start in range(0,len(tokens),30):
  ts=tokens[start:start+30];flags=0;desc=[];lits=[]
  for i,t in enumerate(ts):
   if t[0]:
    flags|=1<<(29-i);desc.append((t[1]<<16)|(t[2]<<9)|t[3])
   else:lits.append(t[1])
  out.append((len(ts)<<30)|flags)
  for j in range(0,len(desc),2):out.append((desc[j]<<18)|(desc[j+1] if j+1<len(desc) else 0))
  out.extend(lits)
 return out

if __name__=='__main__':
 total=[0]*5
 for line in m.MANIFEST.read_text().splitlines()[1:]:
  x=line.split('\t');src=m.load(pathlib.Path(x[0]));baseline=m.encode(src)
  a=pack(tokenize(src));b=pack(tokenize(src,True))
  assert m.decode(a,len(src))==list(src)
  assert m.decode(b,len(src))==list(src)
  assert a==b # even halfword offsets and word matches are equivalent
  vals=[len(src),len(baseline),len(a),len(b),int(x[-1])]
  total=[u+v for u,v in zip(total,vals)]
  print('%s\t%s'%(pathlib.Path(x[0]).name,'\t'.join(map(str,vals))))
 print('TOTAL raw=%d singleton=%d grouped=%d aligned_even=%d v006=%d'%(tuple(total)),file=sys.stderr)
