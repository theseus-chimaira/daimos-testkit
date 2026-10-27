#!/usr/bin/env python3
"""Guard the PI6/VM/provider ownership contract of mapped RENAME."""
from pathlib import Path
import sys

root = Path(sys.argv[1]) / "system/kernel"
syscall = (root / "proc/syscall_dispatch_pdp6.s").read_text()
proc = (root / "proc/proc_pdp6.s").read_text()
vm = (root / "proc/vm_pdp6.s").read_text()
provider = (root / "fs/fs_mres.s").read_text()

def section(text, first, last):
    return text.split(first, 1)[1].split(last, 1)[0]

mapped = section(syscall, "%L112:", "%L119:")
assert "native_sys_two_paths" in mapped
assert "file_rename" in mapped
assert "native_sys_mapped_return" in mapped
assert "vm_user_mapping_release" in section(syscall,
    "native_sys_mapped_return:", "%L66:")

wait = section(proc, "proc_wait_event_common:", "proc_wait_boot:")
for token in ("proc_runq_remove", "PROC_STATE_SLEEP", "proc_sched_kick",
              "cono    0004,004002"):
    assert token in wait, token
pi6 = section(proc, "proc_sched_pi_resched:", "; Called once per qualified")
assert "proc_save_kernel" in pi6 and "proc_sched_restore_selected" in pi6
assert "proc_restore_kernel:" in proc and "CTX_KSP" in proc

hold = section(vm, "vm_user_mapping_hold:", "vm_user_mapping_hold_done:")
release = section(vm, "vm_user_mapping_release:", "vm_user_mapping_release_done:")
assert "0024(5)" in hold and "iori    0,02" in hold
assert "0024(5)" in release and "andcmi  0,02" in release

gateway = section(provider, "fs_provider_serialized:", "; KCORE memory-pressure bridge")
for token in ("fs_provider_lock_retry:", "proc_wait_event",
              "fs_provider_unlock:", "proc_wakeup_event"):
    assert token in gateway, token
print("daimos-rename-pi6-ownership-v468: PASS (static PI6/VM/provider contract)")
