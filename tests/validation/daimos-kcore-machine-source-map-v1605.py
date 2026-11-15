#!/usr/bin/env python3
"""Validate the zero-overhead PDP-6 source selector for later KA10/KI10.

This checks the real original production build inputs; it does not pretend
that a KA10/KI10 image, paging, or machine boot already exists.
"""

import os
import pathlib
import re
import subprocess


root = pathlib.Path(os.environ["DAIMOS_REPO"]).resolve()
kernel = root / "system/kernel"
boot = root / "system/boot/pdp6/Makefile"
manifest_path = kernel / "arch/pdp6_source_map_v1605.mk"
manifest = manifest_path.read_text(encoding="ascii")
km = (kernel / "Makefile").read_text(encoding="ascii")
bm = boot.read_text(encoding="ascii")

expected = {
    "DAIMOS_CPU_PROCESS_SOURCE": "proc/proc_pdp6.s",
    "DAIMOS_CPU_TRAP_SOURCE": "proc/mach_user_pdp6.s",
    "DAIMOS_CPU_PI_SOURCE": "core/kcore_pi_pdp6.s",
    "DAIMOS_CPU_SYSCALL_SOURCE": "proc/syscall_dispatch_pdp6.s",
    "DAIMOS_VM_CONTIG_MM_SOURCE": "mm/mm_pdp6.s",
    "DAIMOS_VM_SWAP_SOURCE": "proc/proc_swap_pdp6.s",
    "DAIMOS_VM_BACKING_SOURCE": "proc/proc_pure_backing_pdp6.s",
    "DAIMOS_CPU_EXEC_LOW_SOURCE": "proc/exec_lowmem_pdp6.s",
    "DAIMOS_CPU_KINIT_IO_SOURCE": "boot/kinit_io_pdp6.s",
    "DAIMOS_CPU_KINIT_LATE_SOURCE": "boot/kinit_late_begin_pdp6.s",
    "DAIMOS_CPU_MODULE_RUNTIME_SOURCE": "modules/module_runtime_pdp6.s",
    "DAIMOS_CPU_BCACHE_SOURCE": "storage/bcache_pdp6.s",
    "DAIMOS_CPU_KFMT_SOURCE": "core/kfmt_pdp6.s",
}

assert "include arch/pdp6_source_map_v1605.mk" in km
assert "include $(KERNEL_DIR)/arch/pdp6_source_map_v1605.mk" in bm
assert "ifneq ($(DAIMOS_MACHINE),pdp6)" in manifest
for name, source in expected.items():
    match = re.search(r"^" + name + r"\s*=\s*(\S+)\s*$", manifest, re.M)
    assert match and match.group(1) == source, (name, match)
    assert (kernel / source).is_file(), (name, source)
    uses = ("$(" + name + ")", "${" + name + "}")
    assert any(use in km or use in bm for use in uses), name

# Fail closed for unsupported CPU targets; do not accidentally emit a
# PDP-6 KCORE under another CPU's name.
result = subprocess.run(
    ["make", "-s", "-n", "DAIMOS_MACHINE=ki10", "kcore"],
    cwd=kernel,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    check=False,
)
assert result.returncode != 0, result.stdout
assert "has no accepted KCORE/boot backend" in result.stdout, result.stdout

print("PASS v1605 PDP-6 source map, dual build includes, fail-closed KI10")
