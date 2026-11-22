#!/usr/bin/env python3
"""Physical PDP-6 RAW PURE MM trace with source-linked fault witness.

User program virtual PCs overlap KCORE physical PCs. Never set a SIMH
breakpoint at a user fixture symbol: it may stop in kernel MM code.
The disposable PID1 holds at CTY checkpoints A/B/C. After A the host
arms SIMH physical -W breakpoints on every original MM extent word and
mm_extent_count. Each watched physical write records the updated word.
There are no KCORE or test-guest instrumentation hooks.
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


def run(argv):
    if len(argv) != 8:
        raise ValueError("usage: host-cty-v1674.py pty-run pdp6 "
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
                    if len(output) > 8000000:
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


            watches = []
            def set_watchpoints(snapshot_text):
                # Reuse the original stable A snapshot. A second EX of
                # mm_extent_capacity would duplicate one physical word
                # inside the CTY checkpoint and rightly fail the strict
                # original v1673 unique-word verifier. Arm watches only;
                # do not re-examine the same monitor/MM address.
                capacity = read_word(snapshot_text, source_symbol(
                    coremap, "mm_extent_capacity"))
                if capacity != 32:
                    raise ValueError("v1674 requires 48K MM capacity 32")
                count = source_symbol(coremap, "mm_extent_count")
                base = source_symbol(coremap, "mm_extents")
                invariant = [source_symbol(coremap, name) for name in
                             ("mm_core_words", "mm_extent_capacity",
                              "mm_arena_count")]
                arenas = source_symbol(coremap, "mm_arenas")
                watches.extend([count] + list(range(base, base + 2 * capacity))
                               + invariant + list(range(arenas, arenas + 3)))
                if len(set(watches)) != len(watches):
                    raise ValueError("duplicate physical MM watch address")
                for addr in watches:
                    examine("break -W %o;ex %o;go\n" % (addr, addr))
                listing = examine("show -C -W break\n")
                found = set(int(v, 8) for v in re.findall(
                    r"^SET BREAK -W ([0-7]+);", listing, re.M))
                if found != set(watches):
                    raise ValueError("SIMH failed to arm all MM write watches")
                print("v1678: armed %d physical MM write watches at A" %
                      len(watches), flush=True)

            def clear_watchpoints():
                for addr in watches:
                    examine("nobreak -W %o\n" % addr)
                listing = examine("show -C -W break\n")
                if "SET BREAK -W " in listing:
                    raise ValueError("SIMH MM write watches survived C")
                print("v1678: disarmed MM write watches at C", flush=True)

            for token in "ABC":
                wait_for("V1673 HOLD " + token, 0, timeout)
                start = len(output)
                send(b"\x05")  # SIMH command prompt, never guest input.
                wait_for("sim> ", start, 20.0)
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
                if token == "B":
                    # The original fixed-KCORE service entry is a
                    # patched JRST to the actual loaded PURE MRES.
                    # Recover that physical MRES base without guessing
                    # the KINIT MM placement, then examine the real
                    # single-shot MM-rebase-refusal fault counter.
                    puremap = os.environ.get("V1678_PURE_MAP")
                    if not puremap:
                        raise ValueError("v1678 requires linked PURE map")
                    patch = examine_word(source_symbol(
                        coremap, "proc_swap_reclaim"))
                    if patch >> 27 != 0o254:
                        raise ValueError("v1678 PURE reclaim not installed")
                    target = patch & 0o777777
                    local = source_symbol(puremap,
                        "proc_pure_mres_reclaim_v1612")
                    count_offset = source_symbol(puremap,
                        "v1678_rebase_fault_count")
                    fault_address = target - local + count_offset
                    if not 0 < fault_address < core:
                        raise ValueError("v1678 invalid relocated MRES data")
                    observed = examine_word(fault_address)
                    if observed != 1:
                        raise ValueError("v1678 actual injected fault count "
                                         "is %o, not 1" % observed)
                    print("PASS v1678: original physical MM rebase-refusal "
                          "fault fired exactly once", flush=True)
                if os.environ.get("V1678_FAST", "0") != "1":
                    if token == "A":
                        set_watchpoints(output[snapshot_start:].decode(
                            "ascii", errors="ignore"))
                    if token == "C":
                        clear_watchpoints()
                start = len(output)
                send(b"go\n")
                time.sleep(0.2)
                send(token.encode("ascii") + b"\r")
                wait_for("V1673 RELEASE " + token, start, 30.0)
                print("v1678: guest physical MM checkpoint " + token,
                      flush=True)
                if token == "B" and os.environ.get("V1673_STOP_AFTER_B") == "1":
                    print("v1673: diagnostic-only stop at B; NOT an accepted recovery run", flush=True)
                    return
            wait_for("V1673 PASS RUN EXIT WAIT", 0, 30.0)
        Path(log).with_suffix(".clean").write_text(
            output.decode("ascii", errors="ignore").replace("\r", ""),
            encoding="ascii")
        print("v1674: genuine PID1 completed native RUN/EXIT/WAIT", flush=True)
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
        raise SystemExit("FAIL v1674 physical MM write watches: " + str(exc))
