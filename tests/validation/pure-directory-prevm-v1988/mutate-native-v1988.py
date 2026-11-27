"""Generate unsafe source controls for the complete original finalizer."""
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
variants=[
    ('ignore-vm-refusal','        jumpe   1,proc_finish_vm_done','        jrst    proc_finish_vm_done'),
    ('no-prevm','        movsi   4,PROC_FINALIZE_MARK_LH+PROC_FINALIZE_PREVM_LH','        movsi   4,PROC_FINALIZE_MARK_LH'),
    ('no-span-escrow','        ior     4,5\n        pushj   17,proc_finish_mark_pending_v892','        jfcl\n        pushj   17,proc_finish_mark_pending_v892'),
    ('no-backoff','        caige   4,01000\n        lsh     4,1','        caige   4,01000\n        jfcl'),
    ('no-stack-guard','proc_exec_stack_busy_v1937:\n','proc_exec_stack_busy_v1937:\n        jrst kret_zero\n'),
    ('no-user-pc','        tlnn    1,010000               ; saved return must be user mode\n        jrst    proc_finish_fail','        jfcl'),
    ('no-wait-guard','        tlne    1,PROC_WAIT_LH_MASK\n        jrst    proc_finish_fail','        jfcl'),
    ('no-file-guard','        skipn   (3)\n        jrst    proc_finish_fd_next_v869\n        jrst    proc_finish_fail','        jrst    proc_finish_fd_next_v869'),
]
for name,a,b in variants:
    assert s.count(a)==1,(name,s.count(a))
    p.with_name(name+'.s').write_text(s.replace(a,b,1))
