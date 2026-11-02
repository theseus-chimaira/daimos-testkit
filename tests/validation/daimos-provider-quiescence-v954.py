#!/usr/bin/env python3
"""Source-contract guard for permanent provider ownership (v954).

This is a static safety check, not a dynamic proof of all asynchronous
interleavings. Runtime provider lock tests remain independent.
"""
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
gateway = (root / 'system/kernel/fs/fs_mres.s').read_text()
proc = (root / 'system/kernel/proc/proc_pdp6.s').read_text()

def section(source, start, end):
    assert source.count(start) == 1, 'missing or duplicate ' + start
    return source.split(start, 1)[1].split(end, 1)[0]

def require(source, text, label):
    assert text in source, label + ': missing ' + text.strip()

serial = section(gateway, 'fs_provider_serialized:', '; KCORE memory-pressure bridge')
acquire = section(serial, 'fs_provider_lock_retry:', 'fs_provider_lock_wait:')
wait = section(serial, 'fs_provider_lock_wait:', 'fs_provider_unlock:')
unlock = section(serial, 'fs_provider_unlock:', 'fs_memfs_service_jump:')
require(acquire, 'hrlzm   0,fs_provider_ready', 'owner publication')
require(acquire, 'pushj   17,@fs_memfs_service_jump(7)', 'provider invocation')
require(acquire, 'jrst    fs_provider_unlock', 'return through unlock')
require(wait, 'pushj   17,proc_wait_event', 'foreign waiter sleep')
require(wait, 'jrst    fs_provider_lock_retry', 'waiter revalidation')
require(wait, 'jrst    kret_neg5', 'recursive owner refusal')
require(unlock, 'setom   fs_provider_ready', 'lease release')
require(unlock, 'setom   fs_provider_wait_event_v917', 'waiter notification')
require(unlock, 'pushj   17,proc_wakeup_event', 'wake invocation')
assert serial.count('setom   fs_provider_ready') == 1, 'unexpected lock release site'

selector = section(proc, 'proc_oom_select_v863:', 'proc_swap_victim:')
require(selector, 'hrrz    1,fs_provider_ready', 'OOM lock probe')
require(selector, 'hlrz    1,fs_provider_ready', 'OOM owner lookup')
require(selector, 'jumpe   1,proc_oom_unknown_provider_v866', 'unknown owner')
require(selector, 'camn    012,1', 'known owner exclusion')
require(selector, 'jrst    proc_oom_next_v863', 'skip lease owner')
require(selector, 'proc_oom_unknown_provider_v866:\n', 'unknown owner refusal')
require(selector, 'seto    014,', 'unknown owner no victim')
require(selector, 'trne    2,PROC_FATAL_CLOSE_BIT', 'fatal stack exclusion')

fatal = section(proc, 'proc_fatal_close_current_v879:', '/**')
require(fatal, 'pushj   17,file_close_all', 'owner private close')
require(fatal, 'pushj   17,proc_sleep_ticks', 'failed close retry')
require(fatal, 'caige   1,01000', 'retry cap')
require(fatal, 'jrst    proc_fatal_close_retry_v879', 'retry without forced release')
assert 'mm_free' not in fatal and 'fs_provider_ready' not in fatal, (
    'fatal retry must not free or unlock a provider')

print('v954: provider owner, waiter, unknown-owner OOM and private retry safety PASS')
