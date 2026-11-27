#!/usr/bin/env python3
"""Booted dirty DROP: actual partial codec store and exact RAW rollback."""
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
old=runpy.run_path(str(HERE.parent/'pure-directory-physical-v1991/replay-v1991.py'))
MASK=old['MASK']
words=old['words']


class DirtyDrop(old['Recovery']):
    def mpc(self,name):
        return self.c['base']+self.c['mres'][name]

    def read_payload(self,label,base=None):
        base=self.source if base is None else base
        return self.inspect([(base,base+self.raw-1)],'RAW_'+label)

    def witness(self,d,e,label,phase,packed=False,pin=1,clean=False):
        s=self.s
        p,vm,sc=self.cells(d,self.slot)
        assert p>>18==self.ua and bool(p&0o200000)==(not clean)
        assert sc>>33 in (2,3,6)
        assert vm==(self.fullwords<<18)|(0 if packed else self.apr)
        assert self.mode(d,self.slot)==(2 if packed else 0)
        expected=(self.source if packed else self.apr,
                  self.apr+self.fullwords,4 if packed else 1,pin,self.slot)
        assert self.owners(e,self.slot)==[expected]
        assert (self.ua,self.ua+0o410,3,0,0o1000+self.slot) in e
        ident=self.identity(d,self.slot,label)
        for k in ('ua','pc','cred','ctl','record'):
            assert ident[k]==self.original_id[k],(label,k)
        assert ident['backing']==ident['record']
        tag=((3 if not phase else 0o13)<<29)|((self.source>>7)<<18)|0o600000|\
            ((self.fullwords>>10)<<7)|(((ident['cred']>>27)&0o37)<<2)|phase
        assert ident['escrow']==(0 if clean else tag),(label,oct(ident['escrow']),oct(tag))
        extra=self.inspect([(self.retry,self.retry),(self.ua+0o407,self.ua+0o407),
            (s['proc_sched_cursor'],s['proc_sched_cursor'])],'EXTRA_'+label)
        assert extra[self.ua+0o407]==self.heap
        assert not extra[s['proc_sched_cursor']]&0o1000
        assert self.read_payload(label)==self.payload
        return extra

    def refuse_leaf(self,pc,label,packed,d,e):
        orig=self.inspect([(pc,pc)],'ORIGINAL_'+label)[pc]
        ret=self.return_pc(label)
        assert ret!=pc
        self.deposit(pc,(0o254000<<18)|self.s['kret_neg1'],'PATCH_'+label)
        dd,ee,ac=self.stop(ret,'REFUSED_'+label)
        self.deposit(pc,orig,'RESTORED_'+label)
        assert ac[1]==(1<<36)-1 and ee==e
        assert self.cells(dd,self.slot)==self.cells(d,self.slot)
        self.witness(dd,ee,'REFUSED_'+label,0,packed)

    def before_pressure(self,**c):
        self.c=c; self.s=c['sym']; self.table=c['table']
        self.modebase=c['modebase']; self.nslots=c['nslots']
        s=self.s
        encode=self.mpc('pbmd_encode_v1977')
        walk=self.mpc('pbmd_walk_v1977')
        image={int(a,8):int(b,8) for a,b in re.findall(
            r'(?m)^IMAGE  ([0-7]{6}) ([0-7]{12})$',c['dxr'])}
        off=c['mres']['pbmd_walk_v1977']
        # The unique encode literal store and the original invalid
        # branch target are identified in the actual linked walker.
        store,=[a for a in range(off,off+0o220) if image.get(a)==0o202343000000]
        invalid,=[a for a in range(store,off+0o220) if image.get(a)==0o211040000004]
        patch=c['base']+store+1
        invalid+=c['base']
        assert image[store+1]>>18==0o254000
        d,e,ac=self.stop(encode,'ENCODE')
        self.source,self.raw,self.apr,skip=(ac[i] for i in range(1,5))
        self.fullwords=self.raw+skip
        assert self.apr+skip==self.source and self.apr%1024==0
        own=[x for x in e if x[:4]==(self.apr,self.apr+self.fullwords,1,1)]
        assert len(own)==1
        self.slot=own[0][4]
        assert self.slot==3 and d[s['proc_current_slot']]==1
        self.ua=self.cells(d,self.slot)[0]>>18
        self.original_id=self.identity(d,self.slot,'ENCODE')
        assert self.original_id['cred']&(1<<31) and not self.original_id['backing']
        assert self.original_id['escrow']==(0o13<<29)|((self.source>>7)<<18)
        advance=s['proc_finish_backoff_advance_v885']
        code=self.inspect([(advance,advance+1)],'BACKOFF_CODE')
        assert code[advance]>>18==0o200200 and code[advance+1]==0o607200400000
        self.retry=code[advance]&MASK
        extra=self.inspect([(self.ua+0o407,self.ua+0o407),(self.retry,self.retry)],'INITIAL')
        self.heap=extra[self.ua+0o407]
        assert not extra[self.retry]>>35
        self.payload=self.read_payload('ENCODE')
        prefix=self.inspect([(self.apr,self.source-1)],'PREFIX_ORIGINAL')
        ret=self.return_pc('ENCODE')
        dd,ee,ac=self.stop(patch,'AFTER_STORE')
        assert ee==e and self.cells(dd,self.slot)==self.cells(d,self.slot)
        actual=self.inspect([(patch-1,patch),(invalid,invalid)],'WALK_CODE')
        assert actual[patch-1]==0o202343000000 and actual[patch]>>18==0o254000
        assert actual[invalid]==0o211040000004
        after=self.inspect([(self.apr,self.source-1)],'PREFIX_DIRTY')
        changed=[a for a in prefix if prefix[a]!=after[a]]
        assert len(changed)==1 and changed[0]==ac[3]
        assert self.read_payload('AFTER_STORE')==self.payload
        self.deposit(patch,(0o254000<<18)|invalid,'PATCH_CODEC')
        dd,ee,ac=self.stop(ret,'ENCODE_FAILED')
        self.deposit(patch,actual[patch],'RESTORED_CODEC')
        assert ac[1]==(1<<36)-6 and ee==e
        assert self.read_payload('ENCODE_FAILED')==self.payload
        assert self.inspect([(self.apr,self.source-1)],'PREFIX_FAILED')==after
        print('v1994 actual partial prefix store, slot%d APR %06o/%d RAW %06o/%d'%
              (self.slot,self.apr,self.fullwords,self.source,self.raw),flush=True)

        rebase=self.mpc('mm_pure_rebase_pinned_v1381')
        recover=self.mpc('proc_pure_dirty_recover_v1993')
        unpin=s['mm_unpin']
        d,e,ac=self.stop(rebase,'REBASE_INITIAL')
        assert tuple(ac[i] for i in range(1,5))==(self.apr,self.slot,skip,self.fullwords)
        self.witness(d,e,'REBASE_INITIAL',0)
        self.refuse_leaf(rebase,'REBASE_INITIAL',False,d,e)
        d,e,ac=self.stop(s['proc_pure_recover_arm_v1902'],'ARM')
        assert ac[1]==self.ua
        self.witness(d,e,'ARM',0)
        previous=d[s['proc_timer_clock']]&0o377777
        for i,delay in enumerate((16,32,64,128),1):
            packed=i>=3
            phase=2 if packed else 1
            d,e,ac=self.stop(advance,'BACKOFF%d'%i)
            x=self.witness(d,e,'BACKOFF%d'%i,phase,packed)
            now=d[s['proc_timer_clock']]&0o377777
            assert d[s['proc_current_slot']]==0
            assert x[self.retry]==((0o400000|delay)<<18)|now
            assert (now-previous)&0o377777>=delay
            previous=now
            d,e,ac=self.stop(recover,'RECOVER%d'%i)
            assert ac[1]==self.slot and d[s['proc_current_slot']]==0
            x=self.witness(d,e,'RECOVER%d'%i,phase,packed)
            assert x[self.retry]==((0o400000|2*delay)<<18)|now
            print('v1994 idle recovery %d phase %d tick %d delay %d'%(i,phase,now,delay),flush=True)
            if i==1:
                d,e,ac=self.stop(rebase,'REBASE_RETRY')
                assert tuple(ac[j] for j in range(1,5))==(self.apr,self.slot,skip,self.fullwords)
                self.witness(d,e,'REBASE_RETRY',0)
                self.refuse_leaf(rebase,'REBASE_RETRY',False,d,e)
            if i in (2,3):
                label='UNPIN_INITIAL' if i==2 else 'UNPIN_RETRY'
                d,e,ac=self.stop(unpin,label)
                assert ac[1]==self.source
                self.witness(d,e,label,0,True)
                self.refuse_leaf(unpin,label,True,d,e)
        ret=self.return_pc('RECOVER4')
        d,e,ac=self.stop(ret,'RECOVERED')
        assert ac[1]==0 and d[s['proc_current_slot']]==0
        self.witness(d,e,'RECOVERED',0,True,0,True)
        print('v1994 original RAW suffix recovered, no READY',flush=True)

    def run(self,**c):
        self.c=c; s=self.s
        d=c['pressure']; e=old['old']['v']['extents'](d,s,64)
        assert d[s['proc_current_slot']]==1
        assert self.mode(d,self.slot)==2 and not self.cells(d,self.slot)[0]&0o200000
        own=self.owners(e,self.slot)
        assert len(own)==1 and own[0][1]-own[0][0]==self.raw and own[0][2:]==(4,0,self.slot)
        assert list(self.read_payload('PRESSURE',own[0][0]).values())==list(self.payload.values())
        # Parent performs typed STOP/TERM waits and closes the PIPE.
        # The normal RAW restore gateway can be entered for slot2 first.
        restore=self.mpc('proc_pure_restore_v1384')
        for i in range(1,9):
            label='RAW_RESTORE%d'%i
            d,e,ac=self.stop(restore,label)
            slot=ac[1]
            assert slot in (2,self.slot) and d[s['proc_current_slot']]==0
            if slot==self.slot:
                own=self.owners(e,slot)
                assert self.mode(d,slot)==2 and len(own)==1 and own[0][2:]==(4,0,slot)
                assert list(self.read_payload('RESTORE',own[0][0]).values())==list(self.payload.values())
                break
            # Reinstalling a breakpoint at the current PC can trap
            # again before the instruction executes. Observe the actual
            # call return first; allow ordinary PREFIX/FULL fallback.
            ret=self.return_pc(label)
            d,e,ac=self.stop(ret,'PEER_RETURN%d'%i)
            print('v1994 peer RAW prefix return %012o'%ac[1],flush=True)
        else:
            raise AssertionError('no original dirty victim RAW restore')
        d,e,ac=self.stop(s['exec_replace_current'],'EXEC')
        assert d[s['proc_current_slot']]==self.slot and self.mode(d,self.slot)==0
        ident=self.identity(d,self.slot,'EXEC')
        assert ident['record']==self.original_id['record'] and ident['ua']==self.ua
        assert not ident['backing'] and not ident['escrow'] and not self.cells(d,self.slot)[0]&0o200000
        d,e,ac=self.stop(s['proc_exec_enter'],'ENTER')
        ident=self.identity(d,self.slot,'ENTER')
        assert ident['ua']==self.ua and ident['record']!=self.original_id['record']
        assert not ident['cred']&(1<<31) and not ident['backing'] and not ident['escrow']
        t=c['wait']('V1987_X',c['send']('nobreak all\nexpect "X"\ncont\necho V1987_X\n'))
        assert re.search(r'(?m)^X\s*V1987_X',t)
        d,e=self.snapshot('X')
        assert d[s['proc_current_slot']]==self.slot and self.mode(d,self.slot)==0
        print('v1994 RAW restored, sparse bytes verified by guest, unmarked EXEC',flush=True)


if __name__=='__main__':
    old['old']['prior']['main'](lifecycle=DirtyDrop())
