#!/usr/bin/env python3
"""Read-only stopped bitmap TERM and post-restore EXEC physical observer."""
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
prior=runpy.run_path(str(HERE.parent/'pure-directory-package-v1983/replay-v1983.py'))
v=runpy.run_path(str(HERE.parent/'pure-directory-physical-v1984/verify-pressure-v1984.py'))
words=prior['words']
MASK=0o777777
MARK=1<<31

class Lifecycle:
    def run(self,**c):
        self.c=c
        self.s=c['sym']
        self.table=c['table']
        self.modebase=c['modebase']
        self.nslots=c['nslots']
        self.full=c['base']+c['mres']['proc_pure_bitmap_restore_v1980']
        self.term=c['base']+c['mres']['proc_pure_term_v1982']
        self.finish=c['base']+c['mres']['mm_pure_bitmap_finish_v1664']
        s=self.s
        m=c['pressure']
        assert m[s['proc_current_slot']]==1 and m[s['proc_high_slot']]==c['children']+2
        e=v['extents'](m,s,64)
        self.initial={}
        for slot in range(2,c['children']+2):
            p,vm,sched=self.cells(m,slot)
            mode=self.mode(m,slot)
            assert p&0o600000==0o400000 and sched>>33==(3 if slot<4 else 6)
            ua=p>>18
            assert (ua,ua+0o410,3,0,0o1000+slot) in e
            own=self.owners(e,slot)
            assert len(own)==1 and own[0][3]==0
            assert (mode in (2,3) and not vm&MASK and own[0][2]==4 or
                    mode==0 and vm&MASK==own[0][0] and own[0][2]==1)
            identity=self.identity(m,slot,'PRESSURE_%d'%slot)
            assert bool(identity['cred']&MARK)==(slot!=2)
            if slot>=4:
                assert identity['pc']&(0o10000<<18)
                assert not (sched>>18)&0o60000
            self.initial[slot]=(mode,own[0],identity)
        assert self.initial[3][0]==3, 'EXEC child was not compressed'
        packed=[i for i in self.initial if i>=4 and self.initial[i][0]==3]
        assert packed,'no compressed stopped child'
        print('v1987 pressure: %d children, compressed stopped=%s, EXEC slot3 mode3'%(c['children'],packed),flush=True)

        # Observe each nonresident terminal leaf, with FULL a forbidden
        # stop until parent has completed exact TERM WAITs.
        nonresident=[i for i in self.initial if i>=4 and self.initial[i][0] in (2,3)]
        for slot in nonresident:
            d,e,ac=self.stop(self.term,'TERM_%d'%slot,(self.full,))
            assert ac[1]==slot and ac[2]==self.table+3*slot
            assert d[s['proc_current_slot']]==1
            mode,owner,identity=self.initial[slot]
            p,vm,sched=self.cells(d,slot)
            assert p&0o600000==0o600000 and sched>>33==6
            assert self.mode(d,slot)==mode and not vm&MASK
            assert self.owners(e,slot)==[owner]
            ident=self.identity(d,slot,'TERM_%d'%slot)
            assert ident['pc']==identity['pc'] and ident['cred']==identity['cred']
            assert ident['record']==ident['backing']==ac[3]==identity['record']
            assert not ident['ctl']&6
            files=c['examine']([(ident['ua']+0o26,ident['ua']+0o65)],'V1987_FILES_%d'%slot)
            assert all(not files[ident['ua']+0o26+2*i] for i in range(16))
            print('v1987 foreign TERM slot%d mode%d owner %06o/%d'%(slot,mode,owner[0],owner[1]-owner[0]),flush=True)
            self.before_terminal_continue(slot,d,e,owner,ident)
            # Continue to a guest WAIT marker rather than rearming current PC.
            t=c['wait']('V1987_K_%d'%slot,c['send']('nobreak all\nexpect "k"\nbreak %06o\ncont\necho V1987_K_%d\n'%(self.full,slot)))
            assert re.search(r'(?m)^k\s*V1987_K_%d'%slot,t)
            d,e=self.snapshot('K_%d'%slot)
            self.retired(d,e,slot)
        t=c['wait']('V1987_L',c['send']('nobreak all\nexpect "L"\nbreak %06o\ncont\necho V1987_L\n'%self.full))
        assert re.search(r'(?m)^k*L\s*V1987_L',t)
        d,e=self.snapshot('L')
        for slot in range(4,c['children']+2):
            self.retired(d,e,slot)
        assert self.mode(d,3)==3 and self.owners(e,3)==[self.initial[3][1]]
        # Now the actual PIPE wake can restore and execute marked slot3.
        d,e,ac=self.stop(self.full,'RESTORE')
        assert ac[1]==3 and d[s['proc_current_slot']]==0
        assert self.mode(d,3)==3 and self.owners(e,3)==[self.initial[3][1]]
        d,e,ac=self.stop(self.finish,'FINISH')
        d,e,ac=self.before_finish_continue(d,e,ac)
        slot,source,encoded,target=(ac[i] for i in range(1,5))
        assert slot==3 and (source,source+encoded,4,1,3) in e
        full=self.cells(d,3)[1]>>18
        assert self.owners(e,3)==sorted([(source,source+encoded,4,1,3),(target,target+full,1,1,3)])
        d,e,ac=self.stop(s['exec_replace_current'],'EXEC',(self.full,))
        assert d[s['proc_current_slot']]==3 and self.mode(d,3)==0
        assert self.cells(d,3)[1]==(full<<18)|target
        assert self.owners(e,3)==[(target,target+full,1,0,3)]
        assert self.cells(d,3)[0]&0o600000==0o400000
        ident=self.identity(d,3,'EXEC')
        assert ident['cred']&MARK and not ident['backing'] and not ident['escrow']
        assert ident['record']==self.initial[3][2]['record']
        # Actual new executable publication, same u-area and slot, no
        # lingering old executable reservation or mutable eligibility.
        d,e,ac=self.stop(s['proc_exec_enter'],'ENTER',(self.full,))
        assert d[s['proc_current_slot']]==3 and self.mode(d,3)==0
        new=self.identity(d,3,'ENTER')
        assert new['ua']==ident['ua'] and new['record'] and new['record']!=ident['record']
        assert not new['cred']&MARK and not new['backing'] and not new['escrow']
        assert not d[s['proc_exec_resv_head_v1933']]
        p,vm,sched=self.cells(d,3)
        assert p&0o600000==0o400000 and sched>>33==2
        assert self.owners(e,3)==[(vm&MASK,(vm&MASK)+(vm>>18),1,0,3)]
        print('v1987 restored marked slot3 executed distinct unmarked replacement, same u-area',flush=True)
        t=c['wait']('V1987_X',c['send']('nobreak all\nexpect "X"\ncont\necho V1987_X\n'))
        assert re.search(r'(?m)^X\s*V1987_X',t)
        d,e=self.snapshot('X')
        assert d[s['proc_current_slot']]==3 and self.mode(d,3)==0

    def before_finish_continue(self,d,e,ac):
        return d,e,ac

    def before_terminal_continue(self,slot,d,e,owner,ident):
        pass

    def snapshot(self,label):
        d=self.c['snapshot'](label)
        return d,v['extents'](d,self.s,64)

    def cells(self,d,slot):
        return tuple(d[self.table+3*slot+i] for i in range(3))

    def mode(self,d,slot):
        return (d[self.modebase+slot//18]>>(2*(slot%18)))&3

    def owners(self,e,slot):
        return [x for x in e if x[4]==slot and x[2] in (1,4)]

    def identity(self,d,slot,label):
        c=self.c
        ua=self.cells(d,slot)[0]>>18
        a=self.s['proc_swap_records']
        rec=c['examine']([(a,a)],'V1987_RECORD_PTR_'+label)[a]+slot
        m=c['examine']([(ua+0o20,ua+0o24),(ua+0o66,ua+0o67),
                        (ua+0o406,ua+0o406),(rec,rec)],'V1987_ID_'+label)
        return dict(ua=ua,pc=m[ua+0o20],ctl=m[ua+0o24],cred=m[ua+0o66],
                    escrow=m[ua+0o67],backing=m[ua+0o406],record=m[rec])

    def stop(self,pc,label,guards=()):
        c=self.c
        cmd='nobreak all\n'+''.join('break %06o\n'%x for x in (pc,)+guards)
        t=c['wait']('V1987_AC_'+label,c['send'](cmd+'cont\necho V1987_HIT_'+label+
                     '\nexamine 1-4\necho V1987_AC_'+label+'\n'))
        assert re.search(r'Breakpoint, PC: %06o\b'%pc,t), 'wrong stop before '+label
        d,e=self.snapshot(label)
        return d,e,words(t)

    def retired(self,d,e,slot):
        p,vm,sched=self.cells(d,slot)
        assert not p&0o400000 and sched>>33==0 and self.mode(d,slot)==0
        assert not self.owners(e,slot)
        assert not any(x[2]==3 and x[4]==0o1000+slot for x in e)

if __name__=='__main__':
    prior['main'](lifecycle=Lifecycle())
