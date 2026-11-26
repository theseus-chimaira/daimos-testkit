#!/usr/bin/env python3
"""Read-only live PI6 and READY_ONCE checkpoints around real mode3 FULL."""
import os
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
prior=runpy.run_path(str(HERE.parent/'pure-directory-package-v1983/replay-v1983.py'))
verify=runpy.run_path(str(HERE.parent/'pure-directory-physical-v1984/verify-pressure-v1984.py'))
binding=runpy.run_path(str(HERE.parent/'pure-k08-pi6-v1946/binding-v1946.py'))
words=prior['words']
MASK=0o777777
READY=0o1000

def hit(trace,pc):
    assert re.search(r'Breakpoint, PC: %06o\b'%pc,trace), 'wrong stop: expected %06o'%pc

class Observer:
    def setup(self,build,work,prefix):
        os.environ['V1946_PROVIDER_BUILD']=str(build)
        binding['prepare'](build,work)
        self.provider=binding['read'](build,work,prefix)

    def capture(self,label):
        c=self.c
        s=c['sym']
        d=c['snapshot'](label)
        names=('proc_sched_cursor','pdp10_pi_level6','proc_current_ptr',
               'proc_swap_records','mach_kernel_sp','proc_sched_kick',
               'proc_runq_head','fs_dtfs_service_jump','fs_tsfs_service_jump',
               'sys_dtc_read_block_jump','storage_pi_tape_jump',
               'storage_dct_tape_jump','storage_clock_tape_jump',
               'proc_sched_pi_tick')
        d.update(c['examine']([(s[n],s[n]) for n in names]+[(1,4)],
                              'V1986_SCALARS_'+label))
        slot=c['slot']
        p=c['table']+3*slot
        ua=d[p]>>18
        rec=d[s['proc_swap_records']]+slot
        d.update(c['examine']([(ua+0o24,ua+0o24),(ua+0o66,ua+0o67),
                               (ua+0o406,ua+0o406),(rec,rec)],
                              'V1986_ID_'+label))
        return d,verify['extents'](d,s,64)

    def stop(self,pc,label,guards=()):
        c=self.c
        command='nobreak all\n'+''.join('break %06o\n'%x for x in (pc,)+guards)
        trace=c['wait']('V1986_HIT_'+label,c['send'](command+'cont\necho V1986_HIT_'+label+'\n'))
        hit(trace,pc)
        return self.capture(label)

    def before_finish(self,**c):
        self.c=c
        s=c['sym']; slot=c['slot']
        self.dispatch=s['proc_sched_restore_selected']
        lo,hi=s['proc_idle_loop'],s['proc_finish_backoff_advance_v885']
        code=c['examine']([(lo,hi-1)],'V1986_IDLE_CODE')
        ret=[i+1 for i,v in code.items() if lo<=i<hi and v==0o260740000000|s['proc_swap_service_one']]
        assert len(ret)==1
        self.ret=ret[0]
        self.service=c['base']+c['mres']['proc_pure_mres_service_v1612']
        loader=c['base']+c['mres']['exec_image_full_bounded_v1391']
        tick=s['proc_sched_pi_tick']
        d,e=self.stop(loader,'LOADER',(self.dispatch,self.ret,c['finish']))
        source=next(x for x in e if x[2:]==(4,1,slot))
        target=next(x for x in e if x[2:]==(1,1,slot))
        assert source[0]%1024 and target[0]%1024==0
        assert d[2]==target[0] and d[4]==target[1]-target[0]
        self.original=d; self.owners=e; self.source=source; self.target=target
        self.payload=c['examine']([(source[0],source[1]-1)],'V1986_PAYLOAD_LOADER')
        self.pinned(d,e)
        d,e=self.stop(tick,'PI6',(self.dispatch,self.ret,c['finish']))
        self.pinned(d,e)
        saved=d[s['pdp10_pi_level6']]
        assert not saved&(0o10000<<18) and saved&MASK
        region=binding['classify'](saved&MASK,d,s,c['base'],self.provider)
        assert d[tick]==0o350040000000|s['proc_timer_clock']
        payload=c['examine']([(source[0],source[1]-1)],'V1986_PAYLOAD_PI6')
        assert payload==self.payload
        self.tick=d[s['proc_timer_clock']]
        print('v1986 real PI6 in %s at %06o, exact pinned bitmap/target'%(region,saved&MASK),flush=True)
        # Existing replay sets the actual finish breakpoint next. Guard
        # against a dispatch or service return before that finish.
        c['wait']('V1986_PRE_FINISH',c['send']('echo V1986_PRE_FINISH\n'))

    def pinned(self,d,e):
        c=self.c; s=c['sym']; slot=c['slot']; p=c['table']+3*slot
        ua=d[p]>>18; rec=d[s['proc_swap_records']]+slot
        assert d[s['proc_current_slot']]==0 and d[s['proc_sched_cursor']]==slot
        assert d[s['proc_current_ptr']]==0
        assert d[p]&0o200000 and d[p]&0o400000 and d[p+2]>>33==2
        assert d[p+1]==(self.target[1]-self.target[0])<<18
        assert (d[c['modebase']+slot//18]>>(2*(slot%18)))&3==3
        assert e==self.owners
        assert d[ua+0o67]==((1<<32)|(3<<29)|((self.source[0]>>7)<<18)|self.target[0])
        assert d[ua+0o406]==d[rec] and d[rec]
        assert d[ua+0o66]&(1<<31) and not d[ua+0o24]&6
        for a in (p,p+1,ua+0o66,ua+0o67,ua+0o406,rec):
            assert d[a]==self.original[a]

    def after_finish(self,**k):
        c=self.c; s=c['sym']; slot=c['slot']
        assert k['slot']==slot and k['source']==self.source[0]
        assert k['target']==self.target[0] and k['encoded']==self.source[1]-self.source[0]
        d,e=self.stop(self.ret,'READY',(self.dispatch,self.service))
        assert d[1]==READY|slot
        assert d[s['proc_sched_cursor']]==READY|slot
        self.published(d,e,0)
        assert d[s['proc_timer_clock']]>self.tick
        # SIMH can immediately re-hit a just-cleared/rearmed current PC.
        # Do not rearm self.ret here: a second real service entry is
        # already forbidden by the service-entry guard.
        d,e=self.stop(self.dispatch,'DISPATCH',(self.service,))
        assert d[1]==slot and d[s['proc_sched_cursor']]==slot
        self.published(d,e,0)
        print('v1986 READY_ONCE consumed by first actual dispatch to slot %d'%slot,flush=True)
        trace=c['wait']('V1986_GUEST_W',c['send']('nobreak all\nexpect "w"\ncont\necho V1986_GUEST_W\n'))
        assert re.search(r'(?m)^w\s*V1986_GUEST_W',trace)
        d,e=self.capture('GUEST')
        self.published(d,e,slot)
        print('v1986 restored slot %d completed actual guest data check'%slot,flush=True)

    def published(self,d,e,current):
        c=self.c; s=c['sym']; slot=c['slot']; p=c['table']+3*slot
        ua=d[p]>>18; rec=d[s['proc_swap_records']]+slot
        assert d[s['proc_current_slot']]==current
        assert d[p]&0o400000 and not d[p]&0o200000 and d[p+2]>>33==2
        assert d[p+1]==((self.target[1]-self.target[0])<<18)|self.target[0]
        assert (d[c['modebase']+slot//18]>>(2*(slot%18)))&3==0
        assert [x for x in e if x[4]==slot and x[2] in (1,4)]==[(self.target[0],self.target[1],1,0,slot)]
        assert not any(x[0]<self.source[1] and self.source[0]<x[1] for x in e)
        assert not d[ua+0o67] and not d[ua+0o406]
        assert d[ua+0o66]==self.original[ua+0o66] and d[rec]==self.original[rec]

if __name__=='__main__':
    prior['main'](Observer())
