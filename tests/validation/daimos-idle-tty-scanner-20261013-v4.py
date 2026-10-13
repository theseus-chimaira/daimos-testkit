#!/usr/bin/env python3
"""Source contract: idle DCS/GE activation must preserve receive mailboxes."""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("daimos", type=Path)
    root = parser.parse_args().daimos
    module = (root / "system/kernel/modules/module_minit.c").read_text()
    make = (root / "system/boot/pdp6/Makefile").read_text()
    proc = (root / "system/kernel/proc/proc_pdp6.s").read_text()
    syscall = (root / "system/kernel/proc/syscall_dispatch_pdp6.s").read_text()
    for device in ("dcs", "ge"):
        io = (root / "system/kernel/drivers" / (device + "_io.s")).read_text()
        name = device + "_idle_arm"
        body = io.split(name + ":", 1)[1].split("popj 17,", 2)
        assert name + ":" in io
        assert "skipe " + device + "_rx_word" in body[0]
        assert "cono " in body[1]
        assert "-X " + name in make
        assert "proc_idle_" + device + "_arm_jump" in module
        assert "proc_idle_" + device + "_arm_jump" in proc
    assert "proc_idle_tty_arm" in syscall
    print("PASS DCS/GE idle scanner installation and mailbox-preservation checks")


if __name__ == "__main__":
    main()
