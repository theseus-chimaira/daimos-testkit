#!/usr/bin/env python3
"""Guard the pre-VM TTY owner retry and the narrowed provider close scope."""
import os
from pathlib import Path

root = Path(os.environ['DAIMOS_REPO']) / 'system/kernel'
proc = (root / 'proc/proc_pdp6.s').read_text()
header = (root / 'proc/proc.h').read_text()
file_runtime = (root / 'fs/file_runtime.s').read_text()
vfs = (root / 'fs/vfs.s').read_text()
dtfs = (root / 'fs/dtfs_runtime.s').read_text()
d6fs = (root / 'fs/d6fs_runtime.s').read_text()

def section(src, first, last):
    return src.split(first, 1)[1].split(last, 1)[0]

assert 'int proc_tty_release_session(' in header
tty = section(proc, 'proc_tty_release_session:', '; Remove only trailing FREE')
assert 'pushj   17,proc_tty_line_try_reset_v897' in tty
assert 'jumpn   1,proc_tty_release_fail_v1081' in tty
assert 'proc_tty_release_fail_v1081:' in tty
assert 'proc_tty_release_fail_v1081:\n        seto    1,' in tty

finish = section(proc, 'proc_finish_vm_retry_v997:', 'proc_finish_uarea_retry_v881:')
tty_idx = finish.index('pushj   17,proc_tty_release_session')
vm_idx = finish.index('pushj   17,vm_space_destroy')
assert tty_idx < vm_idx, 'TTY must release before VM can become VM_NONE'
assert 'jumpn   1,proc_finish_prevm_fail_v1081' in finish
failure = section(proc, 'proc_finish_prevm_fail_v1081:', 'proc_finish_defer_uarea_v881:')
assert 'PROC_FINALIZE_MARK_LH+PROC_FINALIZE_PREVM_LH' in failure
assert 'pushj   17,proc_finish_mark_pending_v892' in failure

# Prove why we retain the serialized gateway/owner retry but do not
# invent a generic I/O-abort path for current FILE close implementations.
assert 'pushj   17,vfs_sync' in file_runtime
assert 'FS_MRES_OP_SYNC' in section(vfs, 'vfs_sync:', '; One 128-word')
assert 'jrst    kret_zero' in section(d6fs, 'd6fs_provider_sync:', '; Publish the opposite')
assert 'jrst    kret_zero' in section(dtfs, 'dtfs_sync:', '; Shared clean DTC')
print('v1081: TTY refusal retains PREVM finalizer, real SYNC scope audited PASS')
