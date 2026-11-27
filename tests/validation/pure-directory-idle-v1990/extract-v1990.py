"""Link original idle deadline, retry scan, armer and backoff.
Only the outer idle loop/interrupt handoff is replaced by a test return."""
from pathlib import Path
import sys
src,w=map(Path,sys.argv[1:])
s=(src/'proc/proc_pdp6.s').read_text()
def extract(a,b):
    assert s.count(a)==1,a
    return a+s.split(a,1)[1].split(b,1)[0]
head='.text\n.globl idle_due_v1990\n.globl proc_finish_service_v881\n.globl proc_pure_recover_arm_v1902\n'
head+=extract('        .equ    PROC_WORDS,3\n','        .text\n')
# Original idle eligibility and epoch update, then actual backoff and scan.
due=extract('proc_idle_loop:\n','        pushj   17,mach_pi_disable\n')
due=due.replace('proc_idle_loop:\n','idle_due_v1990:\n',1).replace('proc_idle_swap_v881','idle_not_due_v1990')
due+='        pushj 17,proc_finish_backoff_advance_v885\n        pushj 17,proc_finish_service_v881\n        movei 1,1\n        popj 17,\nidle_not_due_v1990:\n        setz 1,\n        popj 17,\n'
arm=extract('proc_finish_mark_pending_v892:\n','proc_finish_fail:\n')
scan=extract('proc_finish_service_v881:\n','\n/**\n')
backoff=extract('proc_finish_backoff_advance_v885:\n','\n        .bss\n')
(w/'idle-v1990.s').write_text(head+due+arm+scan+backoff)
# Existing terminal fixture links the actual shared mark helper.
p=w/'prevm.s'
# Export the original helper and remove the duplicate fixture definition.
p.write_text(p.read_text().split('proc_finish_mark_pending_v892:\n',1)[0])
with (w/'idle-v1990.s').open('a') as f:
    f.write('\n.globl proc_finish_mark_pending_v892\n')
# The installed service gateway is a JRST, not a C no-argument call.
with (w/'idle-v1990.s').open('a') as f:
    f.write('\n.globl proc_swap_service_one\nproc_swap_service_one:\n jrst service_gate_v1990\n')
