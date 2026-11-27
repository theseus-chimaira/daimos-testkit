#!/usr/bin/env python3
"""Actual v1990 FULL refusal and original slot-zero rollback/retry.
Fault injection changes only the entry instruction of a currently
stopped MM leaf, for one call. Restore it at its actual return PC.
No deposited owner, register, timer, payload or scheduler state."""
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
old=runpy.run_path(str(HERE.parent/'pure-directory-lifecycle-v1987/replay-v1987.py'))
words=old['words']
MASK=0o777777

class Recovery(old['Lifecycle']):
    def inspect(self, pairs, label):
        return self.c['examine'](pairs,'V1991_'+label)

    def extra(self,label):
        return self.inspect([(self.retry,self.retry),(self.ua+0o407,self.ua+0o407),
            (self.s['proc_sched_cursor'],self.s['proc_sched_cursor']),
            (self.s['proc_swap_pressure_ticks'],self.s['proc_swap_pressure_ticks']),
            (self.source,self.source+self.encoded-1)],'EXTRA_'+label)

    def hold(self,d,e,label,phase,pins=(1,1)):
        assert d[self.s['proc_current_slot']]==0
        assert self.mode(d,3)==3 and self.cells(d,3)==self.initial_cells
        assert self.owners(e,3)==sorted([(self.source,self.source+self.encoded,4,pins[0],3),
            (self.target,self.target+self.fullwords,1,pins[1],3)])
        assert (self.ua,self.ua+0o410,3,0,0o1003) in e
        ident=self.identity(d,3,label)
        for k in ('ua','pc','cred','ctl','backing','record'):
            assert ident[k]==self.original_id[k], (label,k)
        tag=((3 if phase==1 else 0o13)<<29)|((self.source>>7)<<18)|(phase<<15)|self.encoded
        assert ident['escrow']==tag,(label,oct(ident['escrow']),oct(tag))
        x=self.extra(label)
        assert x[self.ua+0o407]==self.heap|((0o1000|(self.target>>10))<<18)
        assert all(x[a]==self.payload[a] for a in range(self.source,self.source+self.encoded))
        return x

    def return_pc(self,label):
        c=self.c
        t=c['wait']('V1991_STACK_'+label,c['send']('examine 17\necho V1991_STACK_'+label+'\n'))
        sp=words(t)[0o17]&MASK
        stack=self.inspect([(sp,sp)],'RETURN_'+label)
        return stack[sp]&MASK

    def deposit(self,pc,value,label):
        c=self.c
        t=c['wait']('V1991_'+label,c['send']('deposit %06o %012o\nexamine %06o\necho V1991_%s\n'%(pc,value,pc,label)))
        assert words(t)=={pc:value}

    def refuse(self,pc,label):
        # We are stopped at the first instruction, before the callee
        # can modify its saved registers, MM table, or stack.
        orig=self.inspect([(pc,pc)],'ORIGINAL_'+label)[pc]
        ret=self.return_pc(label)
        assert ret!=pc
        self.deposit(pc,(0o254000<<18)|self.s['kret_neg1'],'PATCH_'+label)
        d,e,ac=self.stop(ret,'REFUSED_'+label)
        self.deposit(pc,orig,'RESTORED_'+label)
        assert ac[1]==(1<<36)-1
        self.hold(d,e,'REFUSED_'+label,1)
        return d,e

    def before_finish_continue(self,d,e,ac):
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
        # Actual rollback is entered by the real synchronous caller.
        unpin=s['mm_unpin']
        d,e,ac=self.stop(unpin,'UNPIN_INITIAL',(self.full,))
        assert ac[1]==self.target
        self.hold(d,e,'UNPIN_INITIAL',1)
        self.refuse(unpin,'UNPIN_INITIAL')
        arm=self.c['base']+self.c['mres']['proc_pure_bitmap_arm_v1990']
        recover=self.c['base']+self.c['mres']['proc_pure_bitmap_recover_v1989']
        d,e,ac=self.stop(arm,'ARM',(self.full,))
        assert ac[1]==3
        x=self.hold(d,e,'ARM',2)
        assert not x[self.retry]>>35
        # Arming is an actual MRES call into the original fixed armer.
        d,e,ac=self.stop(s['proc_pure_recover_arm_v1902'],'FIXED_ARM',(self.full,))
        assert ac[1]==self.ua
        self.hold(d,e,'FIXED_ARM',2)
        # Read the actual armed epoch at the first real deadline.
        clock=s['proc_timer_clock']
        previous=None
        for i,delay in ((1,0o20),(2,0o40)):
            d,e,ac=self.stop(advance,'BACKOFF%d'%i,(self.full,recover))
            x=self.hold(d,e,'BACKOFF%d'%i,2)
            assert x[self.retry]>>18==0o400000|delay
            now=d[clock]&0o377777
            assert x[self.retry]&MASK==now
            if previous is not None:
                assert (now-previous)&0o377777>=delay
            previous=now
            d,e,ac=self.stop(recover,'RECOVER%d'%i,(self.full,))
            assert ac[1]==3
            x=self.hold(d,e,'RECOVER%d'%i,2)
            assert x[self.retry]>>18==0o400000|(delay*2)
            print('v1991 actual idle recovery %d tick %d delay %d -> %d'%(i,d[clock],delay,delay*2),flush=True)
            if i==1:
                d,e,ac=self.stop(unpin,'UNPIN_RETRY',(self.full,))
                assert ac[1]==self.target
                self.hold(d,e,'UNPIN_RETRY',1)
                self.refuse(unpin,'UNPIN_RETRY')
        # Stop at the actual public recovery return; verify original
        # bitmap unpinned and unmodified, original heap restored.
        ret=self.return_pc('RECOVER2')
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
        print('v1991 recovered original bitmap, actual normal FULL retried',flush=True)
        return d,e,ac

if __name__=='__main__':
    old['prior']['main'](lifecycle=Recovery())
