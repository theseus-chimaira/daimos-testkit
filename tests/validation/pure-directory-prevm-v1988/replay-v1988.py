#!/usr/bin/env python3
"""Actual mode3 foreign terminal with one externally held MM pin."""
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
old=runpy.run_path(str(HERE.parent/'pure-directory-lifecycle-v1987/replay-v1987.py'))
prior=old['prior']
MASK=0o777777
PIN=1<<21
LIFE=(1<<35)|(1<<33)|(1<<32)
TERM=0o400001

class Fault(old['Lifecycle']):
    injected=False
    def before_terminal_continue(self,slot,d,e,owner,ident):
        if self.injected:
            return
        assert self.mode(d,slot)==3 and owner[3]==0
        self.injected=True
        c,s=self.c,self.s
        source,end=owner[:2]
        n=end-source
        ua=ident['ua']
        p=self.table+3*slot
        cell=next(s['mm_extents']+2*i+1 for i in range(d[s['mm_extent_count']])
                  if d[s['mm_extents']+2*i]&MASK==source)
        original=d[cell]
        assert original==(4<<18)|slot
        tag=LIFE|(7<<29)|((source>>7)<<18)|TERM
        span=(n<<18)|source
        clock=s['proc_timer_clock']
        advance=s['proc_finish_backoff_advance_v885']
        code=c['examine']([(advance,advance+3)],'V1988_BACKOFF_CODE')
        assert code[advance]>>18==0o200200 # MOVE 4,retry word
        retry=code[advance]&MASK
        assert retry and retry<source
        assert code[advance+1]>>18==0o607200 # TLNN 4,pending flag
        assert code[advance+1]&MASK==0o400000
        # Only the test's own pin is changed. No injected status, mode,
        # timer, source bytes, scheduler state or return code.
        def pin(value,label):
            t=c['wait']('V1988_'+label,c['send'](
                'deposit %06o %012o\nexamine %06o\necho V1988_%s\n'%(cell,value,cell,label)))
            assert old['words'](t)[cell]==value
        def more(label):
            m=c['examine']([(retry,retry),(ua+0o407,ua+0o407),
                            (source,end-1)],'V1988_EXTRA_'+label)
            return m
        before=more('BEFORE')
        assert not before[retry]>>35
        pin(original|PIN,'PIN')
        # Both idle retry entries must be reached via the real timer.
        for attempt,interval in ((1,0o20),(2,0o40)):
            label='BACKOFF%d'%attempt
            # Never rearm the current terminal PC (SIMH re-hits it).
            # Premature retry must enter through the original finalizer
            # or idle service; guard both different entry addresses.
            dd,ee,ac=self.stop(advance,label,(self.full,s['proc_finish_slot'],s['proc_finish_service_v881']))
            assert dd[s['proc_current_slot']]==0
            self.held(dd,ee,slot,owner,d,p)
            id2=self.identity(dd,slot,label)
            assert id2['record']==id2['backing']==ident['record']
            assert id2['pc']==ident['pc'] and id2['cred']==ident['cred']
            assert id2['escrow']==tag
            m=more(label)
            assert m[ua+0o407]==span
            assert m[retry]>>18==0o400000|interval
            assert (m[retry]&MASK)==(dd[clock]&0o377777)
            assert all(m[a]==before[a] for a in range(source,end))
            if attempt==1:
                assert dd[clock]-d[clock]>=interval
            else:
                assert dd[clock]-previous>=interval
            previous=dd[clock]
            label='RETRY%d'%attempt
            dd,ee,ac=self.stop(self.term,label,(self.full,))
            assert dd[s['proc_current_slot']]==0 and ac[1]==slot and ac[2]==p and ac[3]==ident['record']
            self.held(dd,ee,slot,owner,d,p)
            id2=self.identity(dd,slot,label)
            assert id2['escrow']==tag and id2['record']==id2['backing']==ident['record']
            assert id2['pc']==ident['pc'] and id2['cred']==ident['cred']
            m=more(label)
            assert m[retry]>>18==0o400000|(interval*2)
            assert m[ua+0o407]==span
            assert all(m[a]==before[a] for a in range(source,end))
            print('v1988 slot%d real idle retry %d: tick=%d, delay=%d -> %d, original span/escrow held'%(slot,attempt,dd[clock],interval,interval*2),flush=True)
        pin(original,'RELEASE')
        # Return at the real terminal entry with the external pin gone;
        # normal v1987 guest WAIT and complete lifecycle resume.
        print('v1988 released only external pin at original terminal entry',flush=True)

    def held(self,d,e,slot,owner,initial,p):
        assert self.mode(d,slot)==3 and self.cells(d,slot)==self.cells(initial,slot)
        assert d[p]&0o600000==0o600000
        assert self.owners(e,slot)==[(owner[0],owner[1],4,1,slot)]
        assert (d[p]>>18,(d[p]>>18)+0o410,3,0,0o1000+slot) in e
        assert not d[self.s['proc_exec_resv_head_v1933']]

if __name__=='__main__':
    prior['main'](lifecycle=Fault())
