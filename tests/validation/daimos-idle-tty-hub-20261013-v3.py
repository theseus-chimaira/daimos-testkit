#!/usr/bin/env python3
"""Static integration guard for the disabled-by-default idle TTY hub.

The operational simulator acceptance is separate; source checks prevent
accidental removal of the privilege gate or re-enabling dispatch at boot.
"""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("daimos", type=Path)
    args = parser.parse_args()
    root = args.daimos
    syscall = (root / "system/kernel/proc/syscall_dispatch_pdp6.s").read_text()
    proc = (root / "system/kernel/proc/proc_pdp6.s").read_text()
    header = (root / "system/kernel/proc/syscall.h").read_text()
    for name in ("IDLESET", "IDLEGET", "IDLEGEN", "IDLEWAIT"):
        assert f"SYS_TTYCTL_{name}" in header
    assert "caie    1,1" in syscall.split("native_sys_ttyctl_idle:", 1)[1]
    assert "proc_idle_tty_event" in syscall
    for symbol in ("proc_idle_tty_mask", "proc_idle_tty_ready",
                   "proc_idle_tty_epoch", "proc_idle_tty_mark"):
        assert symbol in proc
    assert "skipn   proc_idle_tty_mask" in proc
    assert "pushj   17,proc_idle_tty_signal" in proc
    for driver in ("cty_io.s", "dcs_io.s", "ge_io.s"):
        body = (root / "system/kernel/drivers" / driver).read_text()
        assert "proc_idle_tty_mark" in body, driver
    print("PASS idle-TTY hub ABI, PID1 gate, and CTY/DCS/GE notifications")


if __name__ == "__main__":
    main()
