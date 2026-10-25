#!/usr/bin/env python3
"""Static gate for the PDP-6 serialized filesystem provider bridge.

This checks key assembly invariants, not dynamic scheduler contention.
"""
import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1]).read_text()

def block(start, end):
    a = source.index(start + ':')
    b = source.index(end + ':', a + len(start) + 1)
    return source[a:b]

def require(section, pattern, message):
    if re.search(pattern, section, re.MULTILINE) is None:
        raise SystemExit('FAIL: ' + message)

entry = block('fs_provider_reg_call', 'fs_provider_serialized')
locked = block('fs_provider_serialized', 'fs_provider_lock_wait')
waiting = block('fs_provider_lock_wait', 'fs_provider_locked_no_service')
unlock = block('fs_provider_unlock', 'fs_memfs_service_jump')
require(entry, r'^\s*subi\s+7,4\b', 'provider ID normalization missing')
require(entry, r'^\s*jumpn\s+7,fs_provider_serialized\b', 'non-MEMFS dispatch missing')
require(entry, r'^\s*jrst\s+\(7\)', 'direct MEMFS dispatch missing')
for pattern, message in (
    (r'^\s*add\s+17,kconst_7_7', 'private stack allocation'),
    (r'^\s*hrli\s+0,1\b', 'save source register'),
    (r'^\s*blt\s+0,\(17\)', 'save AC1..AC7'),
    (r'^\s*fs_provider_lock_retry:', 'retry loop'),
    (r'^\s*setzm\s+fs_provider_ready', 'lock acquisition'),
    (r'^\s*hrli\s+0,-6\(17\)', 'restore source'),
    (r'^\s*blt\s+0,7\b', 'restore AC1..AC7'),
    (r'^\s*sub\s+17,kconst_7_7', 'private stack release'),
    (r'^\s*pushj\s+17,\(7\)', 'provider call'),
    (r'^\s*jrst\s+fs_provider_unlock', 'common unlock'),
):
    require(locked, pattern, message + ' missing')
require(waiting, r'^\s*pushj\s+17,proc_wait_event', 'event wait missing')
require(waiting, r'^\s*jrst\s+fs_provider_lock_retry', 'waiter retry missing')
for pattern, message in (
    (r'^\s*push\s+17,1', 'save provider result'),
    (r'^\s*setom\s+fs_provider_ready', 'lock release'),
    (r'^\s*pushj\s+17,proc_wakeup_event', 'waiter wakeup'),
    (r'^\s*pop\s+17,1', 'restore provider result'),
):
    require(unlock, pattern, message + ' missing')
print('daimos-provider-lock-contract-v325: PASS (static invariants only)')
