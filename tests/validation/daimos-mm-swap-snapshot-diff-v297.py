import re,sys
if len(sys.argv) != 2:
    raise SystemExit("usage: daimos-mm-swap-snapshot-diff-v297.py simh.log")
s=open(sys.argv[1]).read()
def get(x):return {int(a,8):int(b,8) for a,b in re.findall(r'^([0-7]{1,6}):\s*([0-7]{12})$',x,re.M)}
chunks=re.split(r'Breakpoint, PC: (002623|003612|002255|002052) \([^\n]+\)\n',s)
events=[]
for i in range(1,len(chunks),2):events.append((chunks[i],get(chunks[i+1])))
for i,(kind,v) in enumerate(events):
 if i>=len(events)-5:print(i,'pc',kind,'sp=%012o'%v.get(0o17,0),'map=%012o'%v.get(0o41141,0))
last_idx=[i for i,(k,v) in enumerate(events) if k=='002623'][-1]
last=events[last_idx][1]
end=get(s.split('HALT instruction, PC:')[-1]); print('post fault dump count',len(end),'last before',len(last))
changes=[a for a in sorted(last.keys() & end.keys()) if last[a]!=end[a]]
print('CHANGES total',len(changes))
for name,lo,hi in [('pstate',0o25024,0o25146),('stack',0o40350,0o40520),('swap',0o40750,0o41145)]:
 dif=[a for a in changes if lo<=a<=hi]
 print(name, 'changed',len(dif));print(' '.join('%06o:%012o>%012o'%(a,last[a],end[a]) for a in dif[:35]))
for a in (0o17,0o24722,0o24772,0o41141):print('key',oct(a),oct(last.get(a,0)),oct(end.get(a,0)))
