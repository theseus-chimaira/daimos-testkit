#!/usr/bin/env python3
"""Host-only CTY barriers for physical PDP-6 RUN/EXIT/WAIT sampling.

User program virtual PCs overlap KCORE physical PCs. Never set a SIMH
breakpoint at a user fixture symbol: it may stop in kernel MM code.
The disposable PID1 explicitly holds at CTY checkpoints A/B/C.
This controller interrupts the simulator itself, reads original MM
words, continues execution, and releases each guest checkpoint.
"""

import os
import re
import select
import signal
import subprocess
import sys
import time
from pathlib import Path


def source_symbol(path, name):
    content = Path(path).read_text(encoding="ascii")
    found = re.findall(r"^" + re.escape(name) + r"\s+([0-7]+)\s*$",
                       content, re.M)
    if len(found) != 1:
        raise ValueError("missing source-linked KCORE MM symbol " + name)
    return int(found[0], 8)


def snapshot_commands(coremap):
    globals_ = ("mm_core_words", "mm_extent_capacity",
                "mm_extent_count", "mm_arena_count",
                "sys_resident_words_immediate")
    commands = ["ex %o\n" % source_symbol(coremap, name)
                for name in globals_]
    arena = source_symbol(coremap, "mm_arenas")
    extent = source_symbol(coremap, "mm_extents")
    commands.append("ex %o-%o\n" % (arena, arena + 2))
    commands.append("ex %o-%o\n" % (extent, extent + 79))
    return commands


def run(argv):
    if len(argv) != 8:
        raise ValueError("usage: host-cty-v1672.py pty-run pdp6 "
                         "boot.ini kcore.map console.log timeout_seconds "
                         "build_directory")
    pty, simh, ini, coremap, log, timeout, build_dir = argv[1:]
    commands = snapshot_commands(coremap)
    timeout = float(timeout)
    output = bytearray()
    # Mirror the proven shell FIFO controller and hold its input open
    # across every SIMH monitor interruption. The boot script must
    # separately omit its final exit, or CTRL-E makes SIMH quit.
    fifo_path = str(Path(log).with_suffix(".in.fifo"))
    os.mkfifo(fifo_path, 0o600)
    fifo_fd = os.open(fifo_path, os.O_RDWR)
    proc = None
    try:
        proc = subprocess.Popen([pty, "-r", simh, ini],
                                stdin=fifo_fd,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, bufsize=0,
                                cwd=build_dir, start_new_session=True)
        with Path(log).open("wb", buffering=0) as record:

            def wait_for(marker, start, seconds):
                target = marker.encode("ascii")
                deadline = time.monotonic() + seconds
                while True:
                    if target in output[start:]:
                        return
                    if proc.poll() is not None:
                        raise ValueError("simulator exited before " + marker)
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise ValueError("timeout before " + marker)
                    readable, _, _ = select.select([proc.stdout], [], [],
                                                  min(0.3, remaining))
                    if not readable:
                        continue
                    data = os.read(proc.stdout.fileno(), 4096)
                    if not data:
                        raise ValueError("missing CTY bytes before " + marker)
                    record.write(data)
                    output.extend(data)
                    if len(output) > 1000000:
                        raise ValueError("oversized physical SIMH CTY transcript")

            def send(data):
                written = 0
                while written < len(data):
                    written += os.write(fifo_fd, data[written:])

            for token in "ABC":
                wait_for("V1672 HOLD " + token, 0, timeout)
                start = len(output)
                send(b"\x05")  # SIMH command prompt, never guest input.
                wait_for("sim> ", start, 20.0)
                for command in commands:
                    start = len(output)
                    send(command.encode("ascii"))
                    wait_for("sim> ", start, 20.0)
                start = len(output)
                send(b"go\n")
                time.sleep(0.2)
                send(token.encode("ascii") + b"\r")
                wait_for("V1672 RELEASE " + token, start, 30.0)
                print("v1672: guest physical MM checkpoint " + token,
                      flush=True)
            wait_for("V1672 PASS RUN EXIT WAIT", 0, 30.0)
        Path(log).with_suffix(".clean").write_text(
            output.decode("ascii", errors="ignore").replace("\r", ""),
            encoding="ascii")
        print("v1672: genuine PID1 completed native RUN/EXIT/WAIT", flush=True)
    finally:
        if proc is not None:
            try:
                os.killpg(proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait(timeout=5)
            if proc.stdout:
                proc.stdout.close()
        os.close(fifo_fd)
        os.unlink(fifo_path)


if __name__ == "__main__":
    try:
        run(sys.argv)
    except (ValueError, OSError, subprocess.TimeoutExpired) as exc:
        raise SystemExit("FAIL v1672 CTY-controlled physical MM: " + str(exc))
