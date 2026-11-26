"""Generate executable unsafe variants of the original selector."""
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
a,b=s.split('proc_select_runq_start:\n',1)
ready,c=b.split('proc_select_runq_normal_v851:\n',1)
for name,old,new in [
    ('no-ready','        trnn    1,PROC_SCHED_READY_ONCE\n        jrst    proc_select_runq_normal_v851','        jrst    proc_select_runq_normal_v851'),
    ('retain-ready','        movem   1,proc_sched_cursor\n        jrst    proc_select_restore','        jfcl\n        jrst    proc_select_restore'),
    ('ready-no-transition','        trne    2,PROC_TRANSITION_RH\n        jrst    proc_select_runq_normal_v851','        jfcl'),
    ('ready-no-apr','        trnn    2,0777777\n        jrst    proc_select_runq_normal_v851','        jfcl'),
    ('ready-no-state','        caie    2,PROC_STATE_RUN\n        jrst    proc_select_runq_normal_v851','        jfcl'),
]:
    assert ready.count(old)>=1,name
    p.with_name(name+'.s').write_text(a+'proc_select_runq_start:\n'+ready.replace(old,new,1)+'proc_select_runq_normal_v851:\n'+c)
old='proc_select_candidate:\n        move    1,(16)\n        trne    1,PROC_TRANSITION_RH\n        jrst    proc_select_next'
assert s.count(old)==1
p.with_name('normal-no-transition.s').write_text(s.replace(old,'proc_select_candidate:\n        move    1,(16)',1))
