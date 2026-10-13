#!/usr/bin/env python3
"""Research-only v036 token-policy model, all DXR payloads."""
import pathlib, struct
MANIFEST=pathlib.Path('tests/host/d6codec-v006/results-v006.tsv')

def load(path):
 b=path.read_bytes()
 if len(b)%8: raise ValueError('non-word source')
 x=struct.unpack('<'+'Q'*(len(b)//8),b)
 if any(w>>36 for w in x):raise ValueError('not 36bit')
 n=x[1]>>18;r=(n+35)//36
 h=3 if len(x)==3+n+r else 2
 if len(x)!=h+n+r:raise ValueError('bad DXR length')
 return x[h:h+n]

def encode(src):
 """Faithful *policy* model of native encoder, output groups are literal-only or one match."""
 out=[];p=0; n=len(src)
 while p<n:
  rem=n-p
  if src[p]==0:
   size=1
   while size<min(127,rem) and src[p+size]==0:size+=1
   out.extend(((1<<30)|(1<<29),((0x10000|(size<<9))<<18)))
   p+=size;continue
  def word_match(at):
   best=0;dist=0
   for d in range(min(128,at),0,-1):
    if src[at]!=src[at-d]:continue
    q=1
    while q<min(127,n-at) and src[at+q]==src[at+q-d]:q+=1
    if q>best:best=q;dist=d
    if q==127:break
   return best,dist
  best,dist=word_match(p)
  if best>=3:
   out.extend(((1<<30)|(1<<29),((best<<9)|dist)<<18))
   p+=best;continue
  limit=min(30,rem); count=1
  while count<limit:
   if src[p+count]==0:break
   match,_=word_match(p+count)
   if match>=3:break
   count+=1
  out.append(count<<30);out.extend(src[p:p+count]);p+=count
 return out

def decode(x,n):
 out=[];p=0
 while len(out)<n:
  ctrl=x[p];p+=1;count=ctrl>>30
  if not 1<=count<=30:raise ValueError('bad group')
  flags=ctrl&((1<<30)-1);matches=sum((flags>>(29-i))&1 for i in range(count))
  desc=x[p:p+(matches+1)//2];p+=(matches+1)//2;di=0
  for i in range(count):
   if not (flags>>(29-i))&1:out.append(x[p]);p+=1;continue
   d=(desc[di//2]>>(18 if di%2==0 else 0))&0x3ffff;di+=1
   kind=d>>16;length=(d>>9)&127;distance=d&511
   if not 1<=length<=127:raise ValueError('bad descriptor')
   if kind==1 and distance==0:out.extend([0]*length)
   elif kind==0 and 1<=distance<=len(out):
    for _ in range(length):out.append(out[-distance])
   else:raise ValueError('invalid match')
 if len(out)!=n or p!=len(x):raise ValueError('length mismatch')
 return out

if __name__=='__main__':
 import sys
 rows=[]
 for line in MANIFEST.read_text().splitlines()[1:]:
  cols=line.split('\t');path=pathlib.Path(cols[0]);src=load(path);encoded=encode(src)
  if decode(encoded,len(src))!=list(src):raise RuntimeError(path)
  rows.append((path.name,len(src),len(encoded),int(cols[-1])))
  print('%s\t%d\t%d\t%d\t%d'%(rows[-1]+(rows[-1][2]-rows[-1][3],)))
 print('TOTAL files=%d original=%d native_policy=%d v006=%d overhead=%d'%(
  len(rows),sum(r[1] for r in rows),sum(r[2] for r in rows),sum(r[3] for r in rows),sum(r[2]-r[3] for r in rows)),file=sys.stderr)
