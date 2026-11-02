#!/usr/bin/env python3
"""Source-linked check: permanently held provider cannot be stolen."""
import os
from pathlib import Path
root = Path(os.environ['DAIMOS_REPO']) / 'system/kernel'
gateway = (root / 'fs/fs_mres.s').read_text()
proc = (root / 'proc/proc_pdp6.s').read_text()
serial = gateway.split('fs_provider_serialized:', 1)[1].split('; KCORE memory-pressure bridge', 1)[0]
acquire = serial.split('fs_provider_lock_retry:', 1)[1].split('fs_provider_lock_wait:', 1)[0]
wait = serial.split('fs_provider_lock_wait:', 1)[1].split('fs_provider_unlock:', 1)[0]
unlock = serial.split('fs_provider_unlock:', 1)[1].split('fs_memfs_service_jump:', 1)[0]
assert 'hrrz    0,fs_provider_ready' in acquire
assert 'jumpe   0,fs_provider_lock_wait' in acquire
assert 'hrlzm   0,fs_provider_ready' in acquire
assert 'pushj   17,@fs_memfs_service_jump(7)' in acquire
assert 'jrst    fs_provider_unlock' in acquire
assert 'pushj   17,proc_wait_event' in wait
assert 'jrst    fs_provider_lock_retry' in wait
assert 'jrst    kret_neg5' in wait
assert 'setom   fs_provider_ready' not in acquire + wait
assert 'setom   fs_provider_ready' in unlock
assert 'pushj   17,proc_wakeup_event' in unlock
assert serial.count('setom   fs_provider_ready') == 1
fatal = proc.split('proc_fatal_close_current_v879:', 1)[1].split('proc_fatal_close_no_owner_v879:', 1)[0]
assert 'pushj   17,file_close_all' in fatal
assert 'pushj   17,proc_sleep_ticks' in fatal
assert 'jrst    proc_fatal_close_retry_v879' in fatal
assert 'fs_provider_ready' not in fatal
assert 'mm_free' not in fatal
print('v987: lease cannot be stolen or forcibly unlocked on refusal: PASS')
print('v987: no provider quiescence/cancellation protocol; OOM kill OFF')
