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


def read_word(text, addr):
    line = r"^(?:sim> )?%o:\s+([0-7]{12})\s*$" % addr
    matches = re.findall(line, text, re.M)
    if len(matches) != 1:
        raise ValueError("no unique physical word at %o" % addr)
    return int(matches[0], 8)


def run(argv, extra_snapshot=None, before_release=None, after_release=None, settle_snapshot=None):
    if len(argv) != 8:
        raise ValueError("usage: host-cty-v1673.py pty-run pdp6 "
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

            def examine(command):
                start = len(output)
                send(command.encode("ascii"))
                wait_for("sim> ", start, 20.0)
                return output[start:].decode("ascii", errors="ignore")

            def examine_word(addr):
                start = len(output)
                send(("ex %o\n" % addr).encode("ascii"))
                marker = ("%o:" % addr).encode("ascii")
                wait_for(marker.decode("ascii"), start, 20.0)
                line_start = output.find(marker, start)
                wait_for("\n", line_start, 20.0)
                return read_word(output[start:].decode(
                    "ascii", errors="ignore"), addr)

            def examine_range(base, count, core):
                if not (0 < base and 0 < count and base + count <= core):
                    raise ValueError("invalid physical process range %o + %o" %
                                     (base, count))
                examine("ex %o-%o\n" % (base, base + count - 1))

            tokens = os.environ.get("V1673_CTY_TOKENS", "ABC")
            if tokens not in ("ABC", "ABCD"):
                raise ValueError("unsupported CTY barrier sequence")
            for token in tokens:
                wait_for("V1673 HOLD " + token, 0, timeout)
                start = len(output)
                send(b"\x05")  # SIMH command prompt, never guest input.
                wait_for("sim> ", start, 20.0)
                if settle_snapshot is not None:
                    # Optional read-only barrier qualification. Keep its
                    # monitor transcript separately; the original strict
                    # snapshot parser must see one unambiguous MM sample.
                    diagnostic_start = len(output)
                    settle_snapshot(token, coremap, examine, examine_word,
                                    send, wait_for, output)
                    Path(log).with_suffix(".settle-" + token + ".log").write_bytes(
                        output[diagnostic_start:])
                    del output[diagnostic_start:]
                snapshot_start = len(output)
                for command in commands:
                    examine(command)
                # The original two-bit mode map and three-word process
                # descriptors are authoritative. Reading the MM owner
                # kind alone would not establish a committed RAW swap.
                storage = source_symbol(coremap, "proc_storage_runtime_v29")
                proc_ptr = examine_word(source_symbol(coremap, "proc_table"))
                high = examine_word(source_symbol(coremap, "proc_high_slot"))
                rec_ptr = examine_word(source_symbol(coremap, "proc_swap_records"))
                mode_ptr = examine_word(storage)
                mode_slots = examine_word(storage + 1)
                core = read_word(output[snapshot_start:].decode(
                    "ascii", errors="ignore"),
                    source_symbol(coremap, "mm_core_words"))
                if not (1 < high <= mode_slots <= 256):
                    raise ValueError("impossible physical process/mode capacity")
                examine_range(proc_ptr, high * 3, core)
                examine_range(rec_ptr, high, core)
                examine_range(mode_ptr, (high + 17) // 18, core)
                # The packed process's *existing stable u-area* holds
                # the original immutable backing while its runnable
                # APR base is zero. Read that word independently.
                table_dump = output[snapshot_start:].decode(
                    "ascii", errors="ignore")
                for slot in range(1, high):
                    meta = read_word(table_dump, proc_ptr + 3 * slot)
                    if meta & 0o400000:
                        uarea = (meta >> 18) & ((1 << 18) - 1)
                        examine_range(uarea + 0o406, 1, core)
                if extra_snapshot is not None:
                    extra_snapshot(token, coremap, core, examine_word,
                                   examine_range)
                if before_release is not None:
                    before_release(token, coremap, examine, examine_word)
                start = len(output)
                send(b"go\n")
                time.sleep(0.2)
                send(token.encode("ascii") + b"\r")
                wait_for("V1673 RELEASE " + token, start, 30.0)
                print("v1673: guest physical MM checkpoint " + token,
                      flush=True)
                if after_release is not None and after_release(
                        token, coremap, examine, examine_word, examine_range,
                        send, wait_for, output):
                    Path(log).with_suffix(".clean").write_text(
                        output.decode("ascii", errors="ignore").replace("\r", ""),
                        encoding="ascii")
                    return
                if token == "B" and os.environ.get("V1673_STOP_AFTER_B") == "1":
                    print("v1673: diagnostic-only stop at B; NOT an accepted recovery run", flush=True)
                    return
            wait_for("V1673 PASS RUN EXIT WAIT", 0, 30.0)
        Path(log).with_suffix(".clean").write_text(
            output.decode("ascii", errors="ignore").replace("\r", ""),
            encoding="ascii")
        print("v1673: genuine PID1 completed native RUN/EXIT/WAIT", flush=True)
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
        raise SystemExit("FAIL v1673 CTY-controlled physical MM: " + str(exc))
