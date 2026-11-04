#!/usr/bin/env python3
"""Guard the current pre-activation OOM and optional-XIP boundary.

This is a source-level scope contract, not an XIP process-lifecycle test
or permission to enable automatic OOM termination. Negative controls
prove that each checked guard is actually exercised by the fixture.
"""

import os
from pathlib import Path
import re


root = Path(os.environ["DAIMOS_REPO"]) / "system/kernel"
run = (root / "proc/proc_run.s").read_text()
exe = (root / "proc/exec_lowmem_pdp6.s").read_text()
vm = (root / "proc/vm_pdp6.s").read_text()
dispatch = (root / "proc/syscall_dispatch_pdp6.s").read_text()
memfs = (root / "fs/memfs_runtime.s").read_text()


def check(src):
    run, exe, vm, dispatch, memfs = src
    errors = []
    if not re.search(
        r"(?m)^\s*\.equ\s+PROC_OOM_BRK_ENABLED_V1000,0\s*$",
        dispatch,
    ):
        errors.append("production requester OOM is not default OFF")
    if run.count("pushj   17,vm_space_startup") != 1:
        errors.append("RUN normal startup call contract changed")
    if exe.count("pushj   17,vm_space_startup") != 2:
        errors.append("EXEC normal startup call contract changed")
    if "movem   3,(11)" not in vm.split("vm_space_startup:", 1)[-1]:
        errors.append("ordinary startup no longer has known user write")
    for name, body in (("RUN", run), ("EXEC", exe),
                       ("syscall dispatch", dispatch)):
        if re.search(r"(?i)\b(?:memfs_xip_admit|memfs_mres_xip_admit|"
                     r"FS_MRES_OP_XIP_ADMIT)\b", body):
            errors.append(name + " now references XIP admission")
        if re.search(r"(?m)^\s*(?:movei|cain)\s+6,027\s*;.*XIP", body):
            errors.append(name + " now references XIP operation 027")
    if "cain    6,027" not in memfs or \
            "memfs_mres_xip_admit:" not in memfs:
        errors.append("MEMFS private XIP operation 027 changed")
    if "movei   6,026" not in vm or \
            "vm_space_destroy_xip_other_v1094:" not in vm:
        errors.append("existing XIP VM release path changed")
    return errors


original = (run, exe, vm, dispatch, memfs)
assert not check(original), "v1123: " + "; ".join(check(original))

mutants = (
    (0, "pushj   17,vm_space_startup", "pushj   17,kret_zero"),
    (1, "pushj   17,vm_space_startup", "pushj   17,kret_zero"),
    (2, "movem   3,(11)", "move    3,(11)"),
    (3, ".equ    PROC_OOM_BRK_ENABLED_V1000,0",
     ".equ    PROC_OOM_BRK_ENABLED_V1000,1"),
    (4, "cain    6,027", "cain    6,026"),
    (0, "pushj   17,vm_space_startup",
     "pushj   17,memfs_xip_admit\n        pushj   17,vm_space_startup"),
)
for i, old, new in mutants:
    assert old in original[i], "v1123: source anchor drift in mutant"
    changed = list(original)
    changed[i] = changed[i].replace(old, new, 1)
    assert check(changed), "v1123: unsafe scope mutation escaped detection"

print("v1123: OOM remains OFF; RUN/EXEC both use writing startup; "
      "MEMFS XIP admission is not wired through the ordinary "
      "process loaders; six unsafe mutations rejected PASS")
print("v1123: scope audit only -- not scheduled XIP proof or OOM readiness")
