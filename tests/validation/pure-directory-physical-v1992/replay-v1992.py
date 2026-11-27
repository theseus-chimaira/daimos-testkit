#!/usr/bin/env python3
"""Actual FULL FREE and SOURCE refusals and original slot-zero retries.

Reuse v1991's one-call instruction refusal and observation protocol.
No injected process, MM, pin, scheduler or clock state.
"""
from pathlib import Path
import runpy

HERE=Path(__file__).resolve().parent
old=runpy.run_path(str(HERE.parent/'pure-directory-physical-v1991/replay-v1991.py'))
MASK=old['MASK']


class Recovery(old['Recovery']):
    def hold(self,d,e,label,phase,pins=(1,1)):
        # pins[1] == None: the original target interval is absent.
        assert d[self.s['proc_current_slot']]==0
        assert self.mode(d,3)==3 and self.cells(d,3)==self.initial_cells
        target=self.target if pins[1] is not None else 0
        expected=[(self.source,self.source+self.encoded,4,1,3)]
        if target:
            expected.append((target,target+self.fullwords,1,pins[1],3))
        assert pins[0]==1
        assert self.owners(e,3)==sorted(expected)
        # Compare ALL owners, not merely the target process's records.
        assert e==sorted([x for x in self.original_extents if x[4]!=3 or
            x[2] not in (1,4)]+expected)
        ident=self.identity(d,3,label)
        for k in ('ua','pc','cred','ctl','backing','record'):
            assert ident[k]==self.original_id[k], (label,k)
        tag=((3 if phase==1 else 0o13)<<29)|((self.source>>7)<<18)|(phase<<15)|self.encoded
        assert ident['escrow']==tag,(label,oct(ident['escrow']),oct(tag))
        x=self.extra(label)
        assert x[self.ua+0o407]==self.heap|((0o1000|(target>>10))<<18)
        assert not x[self.s['proc_sched_cursor']]&0o1000
        assert all(x[a]==self.payload[a] for a in self.payload)
        return x

    def refuse(self,pc,label,pins=(1,1)):
        orig=self.inspect([(pc,pc)],'ORIGINAL_'+label)[pc]
        ret=self.return_pc(label)
        assert ret!=pc
        self.deposit(pc,(0o254000<<18)|self.s['kret_neg1'],'PATCH_'+label)
        d,e,ac=self.stop(ret,'REFUSED_'+label,(self.full,))
        self.deposit(pc,orig,'RESTORED_'+label)
        assert ac[1]==(1<<36)-1
        self.hold(d,e,'REFUSED_'+label,1,pins)

    def before_finish_continue(self,d,e,ac):
        self.original_extents=e
        s=self.s
        self.source,self.encoded,self.target=(ac[i] for i in (2,3,4))
        assert ac[1]==3
        self.initial_cells=self.cells(d,3)
        self.fullwords=self.initial_cells[1]>>18
        self.ua=self.initial_cells[0]>>18
        self.original_id=self.identity(d,3,'ORIGINAL')
        advance=s['proc_finish_backoff_advance_v885']
        code=self.inspect([(advance,advance+1)],'BACKOFF_CODE')
        assert code[advance]>>18==0o200200 and code[advance+1]==0o607200400000
        self.retry=code[advance]&MASK
        x=self.extra('ORIGINAL')
        self.payload={a:x[a] for a in range(self.source,self.source+self.encoded)}
        self.heap=x[self.ua+0o407]&~(0o1777<<18)
        assert self.heap>>18==self.fullwords and self.heap&MASK==self.fullwords
        assert not x[self.retry]>>35
        self.hold(d,e,'INITIAL',1)
        self.refuse(self.finish,'FINISH')
        free=s['mm_free']
        unpin=s['mm_unpin']
        # The real target unpin has succeeded. Refuse target FREE.
        d,e,ac=self.stop(free,'FREE_INITIAL',(self.full,))
        assert (ac[1],ac[2],ac[3])==(self.target,1,3)
        self.hold(d,e,'FREE_INITIAL',1,(1,0))
        self.refuse(free,'FREE_INITIAL',(1,0))
        arm=self.c['base']+self.c['mres']['proc_pure_bitmap_arm_v1990']
        recover=self.c['base']+self.c['mres']['proc_pure_bitmap_recover_v1989']
        d,e,ac=self.stop(arm,'ARM',(self.full,))
        assert ac[1]==3
        assert not self.hold(d,e,'ARM',3,(1,0))[self.retry]>>35
        d,e,ac=self.stop(s['proc_pure_recover_arm_v1902'],'FIXED_ARM',(self.full,))
        assert ac[1]==self.ua
        self.hold(d,e,'FIXED_ARM',3,(1,0))
        clock=s['proc_timer_clock']
        previous=d[clock]&0o377777
        for i,delay in enumerate((16,32,64,128),1):
            phase,pins=(3,(1,0)) if i<=2 else (4,(1,None))
            d,e,ac=self.stop(advance,'BACKOFF%d'%i,(self.full,recover))
            x=self.hold(d,e,'BACKOFF%d'%i,phase,pins)
            now=d[clock]&0o377777
            assert x[self.retry]==((0o400000|delay)<<18)|now
            assert (now-previous)&0o377777>=delay
            previous=now
            d,e,ac=self.stop(recover,'RECOVER%d'%i,(self.full,))
            assert ac[1]==3
            x=self.hold(d,e,'RECOVER%d'%i,phase,pins)
            assert x[self.retry]==((0o400000|delay*2)<<18)|now
            print('v1992 idle recovery %d phase %d tick %d delay %d -> %d'%
                  (i,phase,d[clock],delay,delay*2),flush=True)
            if i==1:
                d,e,ac=self.stop(free,'FREE_RETRY',(self.full,))
                assert (ac[1],ac[2],ac[3])==(self.target,1,3)
                self.hold(d,e,'FREE_RETRY',1,(1,0))
                self.refuse(free,'FREE_RETRY',(1,0))
            if i in (2,3):
                # The actual target FREE has now committed; the saved
                # BRK target field MUST be zero before source unpin.
                label='SOURCE_INITIAL' if i==2 else 'SOURCE_RETRY'
                d,e,ac=self.stop(unpin,label,(self.full,))
                assert ac[1]==self.source
                self.hold(d,e,label,1,(1,None))
                self.refuse(unpin,label,(1,None))
        # Stop at the actual public recovery return; verify original
        # bitmap unpinned and unmodified, original heap restored.
        ret=self.return_pc('RECOVER4')
        d,e,ac=self.stop(ret,'RECOVERED',(self.full,))
        assert ac[1]==0 and d[s['proc_current_slot']]==0
        assert self.mode(d,3)==3 and self.cells(d,3)[0]==(self.initial_cells[0]&~0o200000)
        assert self.cells(d,3)[1:]==self.initial_cells[1:]
        assert self.owners(e,3)==[(self.source,self.source+self.encoded,4,0,3)]
        ident=self.identity(d,3,'RECOVERED')
        assert not ident['escrow'] and ident['record']==ident['backing']==self.original_id['record']
        x=self.extra('RECOVERED')
        assert x[self.ua+0o407]==self.heap
        assert not x[s['proc_sched_cursor']]&0o1000
        assert all(x[a]==self.payload[a] for a in self.payload)
        # All retry work must retire before the next ordinary FULL.
        d,e,ac=self.stop(self.full,'RESTORE_RETRY')
        assert ac[1]==3 and d[s['proc_current_slot']]==0
        assert self.owners(e,3)==[(self.source,self.source+self.encoded,4,0,3)]
        x=self.extra('RESTORE_RETRY')
        assert not x[self.retry]>>18 and x[self.ua+0o407]==self.heap
        assert all(x[a]==self.payload[a] for a in self.payload)
        d,e,ac=self.stop(self.finish,'FINISH_RETRY')
        assert ac[1]==3 and ac[2]==self.source and ac[3]==self.encoded
        print('v1992 recovered original bitmap, actual normal FULL retried',flush=True)
        return d,e,ac

if __name__=='__main__':
    old['old']['prior']['main'](lifecycle=Recovery())
