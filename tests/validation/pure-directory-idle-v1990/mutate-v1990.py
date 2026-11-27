#!/usr/bin/env python3
"""Actual service/idle negative controls, not synthetic assertions."""
from pathlib import Path
import sys
src,w=map(Path,sys.argv[1:])
service=(w/'service-v1990.c').read_text()
restore=(src/'proc/proc_pure_ram_restore_v1391.c').read_text()
idle=(w/'idle-v1990.s').read_text()
variants=[
    ('no-arm',service,'(void)proc_pure_bitmap_arm_v1990(slot);','(void)0;'),
    ('no-route',service,'return proc_pure_bitmap_recover_v1989(slot);','return -1;'),
    ('clobber-cursor',service,'if (ppure_mode3_v1667(slot))\n                        return proc_pure_bitmap_recover_v1989(slot);','if (ppure_mode3_v1667(slot)) {\n                        proc_sched_cursor = slot;\n                        return proc_pure_bitmap_recover_v1989(slot);\n                }'),
    ('raw-to-bitmap',service,'if (ppure_mode3_v1667(slot))\n                        return proc_pure_bitmap_recover_v1989(slot);','return proc_pure_bitmap_recover_v1989(slot);'),
    ('rearm-every-retry',restore,'rc = pbr_rollback_v1989(slot, &id, source, encoded, target, phase);','rc = proc_pure_recover_arm_v1902(id.uarea);\n        u[PROC_FINALIZE_OFFSET] = id.escrow;\n        rc = pbr_rollback_v1989(slot, &id, source, encoded, target, phase);'),
    ('early-retry',idle,'        camge   1,3\n        jrst    idle_not_due_v1990','        jfcl'),
    ('no-backoff',idle,'        pushj 17,proc_finish_backoff_advance_v885','        jfcl'),
    ('scan-hold',idle,'        tlnn    4,PROC_SWAP_RETRY_LH\n        jrst    proc_finish_service_next_v881','        jfcl'),
]
for name,s,old,new in variants:
    assert s.count(old)==1,name
    (w/(name+('.s' if s==idle else '.c'))).write_text(s.replace(old,new,1))
