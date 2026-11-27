"""Extract complete original finalizer/reaper and exact ownership guards."""
from pathlib import Path
import sys
src,w=map(Path,sys.argv[1:])
s=(src/'proc/proc_pdp6.s').read_text()
def extract(t,a,b):
    assert t.count(a)==1
    return a+t.split(a,1)[1].split(b,1)[0]
head='.text\n.globl proc_finish_slot\n.globl proc_finish_service_v881\n.globl proc_finish_backoff_advance_v885\n'
head+=extract(s,'        .equ    PROC_WORDS,3\n','        .text\n')
body=extract(s,'proc_parent_waitable_v1768:\n','\n/**\n')
body+=extract(s,'proc_finish_slot:\n','\nproc_slot_discard:\n')
body+=extract(s,'proc_uarea_release:\n','\n/**\n')
body+=extract(s,'proc_finish_backoff_advance_v885:\n','\n        .bss\n')
guard=(src/'proc/proc_pure_backing_pdp6.s').read_text()
body+=extract(guard,'proc_exec_stack_busy_v1937:\n','\n; Release exactly')
(w/'finalizer-v1988.s').write_text(head+'\n.globl backoff_v1988\n.globl proc_finish_mark_pending_v892\n'+body.replace('proc_finish_backoff_advance_v885:\n','backoff_v1988:\nproc_finish_backoff_advance_v885:\n',1))
# Old embedded fixture still links prevm_v1982; remove its duplicate
# actual marker routine and resolve that original label externally.
p=w/'prevm.s'
t=p.read_text()
p.write_text(t.split('proc_finish_mark_pending_v892:\n',1)[0])
