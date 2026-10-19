#!/usr/bin/env python3
"""Capture PDP-6 SIMH Type-136/551 state during a stalled tape boot.

Usage: daimos-simh-dtc-snapshot-v26.py SIMH BOOT.INI OUTPUT.LOG

No image modifications or simulator internals are required. SIMH receives a
console interrupt through a PTY, then read-only EXAMINE commands. The program
does not assume that a guest LOGIN prompt has been reached.
"""

import os
import pty
import select
import subprocess
import sys
import time
from pathlib import Path


def main():
    if len(sys.argv) != 4:
        sys.exit("usage: daimos-simh-dtc-snapshot-v26.py SIMH BOOT.INI OUTPUT.LOG")
    simh, boot, logfile = map(lambda s: Path(s).resolve(), sys.argv[1:])
    master, slave = pty.openpty()
    env = dict(os.environ)
    env["TERM"] = "dumb"
    env["SDL_VIDEODRIVER"] = "dummy"
    runtime = float(env.get("DAIMOS_SIMH_SNAPSHOT_DELAY_V26", "15"))
    proc = subprocess.Popen([str(simh), str(boot)], stdin=slave,
                            stdout=slave, stderr=slave, env=env)
    os.close(slave)
    logfile.parent.mkdir(parents=True, exist_ok=True)

    def drain(f, seconds):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline and proc.poll() is None:
            ready, _, _ = select.select([master], [], [], 0.25)
            if ready:
                try:
                    data = os.read(master, 65536)
                except OSError:
                    break
                if not data:
                    break
                f.write(data)
                f.flush()

    try:
        with open(logfile, "wb", buffering=0) as f:
            drain(f, runtime)
            f.write(b"\n[HOST] SIMH console stop and read-only snapshot\n")
            os.write(master, b"\x05")
            drain(f, 2)
            queries = ("ex PC", "ex 024355", "ex 024366", "ex 024357",
                       "ex 000046", "ex 000047", "ex DCT STATUS",
                       "ex DCT BUFF", "ex DCT ACC", "ex DTC DTSA",
                       "ex DTC DTSB", "ex DTC CMD[0:3]",
                       "ex DTC DSTATE[0:3]", "ex DTC POS[0:3]",
                       "ex DCT STATUS[0:1]")
            for cmd in queries:
                f.write(("\n[HOST] " + cmd + "\n").encode())
                os.write(master, (cmd + "\r").encode())
                drain(f, 0.35)
            os.write(master, b"exit\r")
            drain(f, 1)
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=4)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=4)
        os.close(master)
    print(logfile)


if __name__ == "__main__":
    main()
