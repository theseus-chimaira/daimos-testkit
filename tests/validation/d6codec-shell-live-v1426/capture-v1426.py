#!/usr/bin/env python3
"""Read-only PDP-6 SIMH snapshot of a genuinely booted DSH process.

Boots isolated copies of existing media, logs in on CTY, stops the
emulator with Ctrl-E, and examines only the selected process's
resident physical user extent. Does not patch or instrument the guest.
"""
import argparse
import json
import os
from pathlib import Path
import pty
import re
import select
import shutil
import signal
import struct
import subprocess
import termios
import time
import tty

WORD_MASK = (1 << 36) - 1
LOW18 = (1 << 18) - 1
DSH_TEXT_SIGNATURE = ("_start", "dsh_state_init", "dsh_heap_alloc",
                      "dsh_execute_line", "main")


def read_dxr(path):
    raw = path.read_bytes()
    if len(raw) % 8:
        raise ValueError("misaligned DXR")
    values = list(struct.unpack("<%dQ" % (len(raw) // 8), raw))
    image = values[1] >> 18
    text = values[2] >> 18
    if (values[0] >> 18) != 0o447062 or text > image:
        raise ValueError("unexpected DSH DXR")
    return values[3:3 + image], image, text


def map_symbols(path):
    result = {}
    for line in path.read_text().splitlines():
        fields = line.split()
        if len(fields) == 2 and re.fullmatch(r"[0-7]{1,7}", fields[1]):
            result[fields[0]] = int(fields[1], 8)
    for name in (*DSH_TEXT_SIGNATURE,):
        if name in ("_start", "main", "dsh_state_init",
                    "dsh_heap_alloc", "dsh_execute_line") and name not in result:
            raise ValueError("missing DSH map symbol: " + name)
    return result


def isolate_media(boot, out):
    root = boot.resolve().parent
    out.mkdir(parents=True, exist_ok=True)
    content = boot.read_text()
    copied = {}
    for line in content.splitlines():
        parts = line.split()
        if len(parts) < 4 or parts[0].lower() != "attach":
            continue
        original = Path(parts[-1])
        if not original.is_absolute():
            original = (boot.parent / original).resolve()
        if not original.is_relative_to(root):
            raise ValueError("attachment outside boot tree: " + str(original))
        rel = original.relative_to(root)
        target = out / "media" / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        if original not in copied:
            if original.exists():
                shutil.copyfile(original, target)
            else:
                target.touch()
            copied[original] = target
        content = content.replace(str(original), str(target))
    content = re.sub(
        r"(?m)^set -q -n log .+$",
        "set -q -n log " + str(out / "simh-v1426.log"), content)
    content = re.sub(r"(?m)^set dpy .+$", "set dpy disable", content)
    content = re.sub(r"(?m)^set wcnsls .+$",
                     "set wcnsls disable", content)
    content = re.sub(r"(?m)^set ocnsls .+$",
                     "set ocnsls disable", content)
    # The console sampler owns the emulator until explicit EXIT.
    lines = content.splitlines()
    if lines.count("go 020") != 1 or lines[-1].strip() != "exit":
        raise ValueError("expected a stock GO 020 and EXIT boot script")
    content = "\n".join(lines[:-1]) + "\n"
    final = out / "boot-headless-v1426.ini"
    final.write_text(content)
    return final, {str(x): str(y) for x, y in copied.items()}


class Console:
    def __init__(self, simh, ini, work):
        master, slave = pty.openpty()
        tty.setraw(slave)
        self.master = master
        self.proc = subprocess.Popen(
            [str(simh), str(ini)], stdin=slave, stdout=slave,
            stderr=slave, close_fds=True, start_new_session=True,
            env={**os.environ, "TERM": "dumb", "SDL_VIDEODRIVER": "dummy"})
        os.close(slave)
        os.set_blocking(master, False)
        self.pending = b""
        self.raw = open(work / "console-v1426.log", "wb", buffering=0)

    def take(self, marker, timeout):
        deadline = time.monotonic() + timeout
        marker = marker if isinstance(marker, bytes) else marker.encode("ascii")
        while marker not in self.pending:
            if self.proc.poll() is not None:
                raise RuntimeError(
                    "SIMH exited before " + repr(marker) +
                    " (exit code " + str(self.proc.returncode) + ")")
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(
                    "SIMH timeout awaiting " + repr(marker) +
                    "; console tail: " + repr(self.pending[-250:]))
            ready, _, _ = select.select(
                [self.master], [], [], min(remaining, 0.25))
            if ready:
                try:
                    data = os.read(self.master, 65536)
                except BlockingIOError:
                    continue
                if not data:
                    raise RuntimeError("SIMH PTY closed")
                self.raw.write(data)
                self.pending += data
                if len(self.pending) > 4 * 1024 * 1024:
                    raise RuntimeError("unbounded console buffer")
        idx = self.pending.index(marker) + len(marker)
        result = self.pending[:idx]
        self.pending = self.pending[idx:]
        return result.decode("latin-1")

    def send(self, msg):
        if isinstance(msg, str):
            msg = msg.encode("ascii")
        os.write(self.master, msg)

    def guest(self, line, timeout=70):
        self.send(line + "\r")
        return self.take("# ", timeout)

    def stop(self):
        self.send(b"\x05")
        return self.take("sim> ", 15)

    def command(self, text, timeout=18):
        # Each exact response ends at the next SIMH debugger prompt.
        self.send(text + "\r")
        return self.take("sim> ", timeout)

    def close(self):
        try:
            if self.proc.poll() is None:
                try:
                    self.command("exit", 3)
                except Exception:
                    pass
                if self.proc.poll() is None:
                    self.proc.terminate()
                    try:
                        self.proc.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        self.proc.kill()
                        self.proc.wait(timeout=3)
        finally:
            self.raw.close()
            os.close(self.master)


def parse_examine(text, addr, count):
    found = {}
    for address, value in re.findall(
            r"(?m)(?:^|\n)(?:sim>\s*)?([0-7]{1,7}):\s*"
            r"([0-7]{1,12})(?=\s|$)", text):
        a = int(address, 8)
        if a in found:
            raise ValueError("duplicate SIMH examine address")
        found[a] = int(value, 8)
    expected = list(range(addr, addr + count))
    if sorted(found) != expected:
        raise ValueError(
            "SIMH examine mismatch: expected %d at %06o, got %d"
            % (count, addr, len(found)))
    return [found[p] for p in expected]


def examine(console, addr, count):
    if count < 1 or addr < 0 or addr + count > 0o1000000:
        raise ValueError("invalid physical examine range")
    words = []
    for start in range(addr, addr + count, 64):
        n = min(64, addr + count - start)
        cmd = "ex %06o" % start
        if n > 1:
            cmd += "-%06o" % (start + n - 1)
        text = console.command(cmd, 24)
        words.extend(parse_examine(text, start, n))
    return words


def find_shell(console, kmap, dmap, payload, image, text_size):
    required = ("proc_table", "proc_high_slot", "proc_current_slot")
    if any(x not in kmap for x in required):
        raise ValueError("missing linked KCORE descriptor symbols")
    ptr = examine(console, kmap["proc_table"], 1)[0] & LOW18
    high = examine(console, kmap["proc_high_slot"], 1)[0] & LOW18
    current = examine(console, kmap["proc_current_slot"], 1)[0] & LOW18
    if not (ptr and 1 < high <= 64 and current < high):
        raise ValueError("invalid process table metadata")
    table = examine(console, ptr, high * 3)
    candidates = []
    for slot in range(1, high):
        meta, vm, sched = table[3 * slot:3 * slot + 3]
        base = vm & LOW18
        extent = vm >> 18
        if not base or extent < image + 0o20 or base + extent > 0o1000000:
            continue
        if (sched >> 33) & 7 not in (2, 3, 4, 5, 6):
            continue
        # All test offsets are genuine DSH instruction entry points
        # from the exact current linker map. Relocation changes the
        # address field but not the opcode or register field.
        signature = []
        for name in DSH_TEXT_SIGNATURE:
            logical = dmap[name]
            index = logical - 0o20
            if not 0 <= index < text_size:
                raise ValueError("symbol outside DSH code")
            actual = examine(console, base + logical, 1)[0]
            signature.append(
                (actual >> 18) == (payload[index] >> 18))
        if all(signature):
            candidates.append({
                "slot": slot, "base": base, "extent": extent,
                "sched": sched, "meta": meta, "current": slot == current,
                "signature": signature,
            })
    if len(candidates) != 1:
        raise ValueError("expected unique resident DSH, got " +
                         repr(candidates))
    return candidates[0]


def capture(console, label, result_dir, kmap, dmap,
            payload, image, text_size):
    result_dir.mkdir(parents=True, exist_ok=True)
    shell = find_shell(console, kmap, dmap, payload, image, text_size)
    prefix = (0o20 + text_size) // 0o200 * 0o200
    writable = 0o20 + text_size
    if not (prefix < writable < shell["extent"]):
        raise ValueError("invalid real process suffix geometry")
    phys = shell["base"] + prefix
    count = shell["extent"] - prefix
    # Entire actual process suffix, including initialized text tail,
    # mutable DATA/BSS/heap and stack, without reading another process.
    data = examine(console, phys, count)
    if not all(0 <= w <= WORD_MASK for w in data):
        raise ValueError("non-36-bit SIMH word")
    binary = result_dir / (label + "-physical-suffix-v1426.bin")
    binary.write_bytes(struct.pack("<%dQ" % len(data), *data))
    details = {**shell, "label": label, "prefix": prefix,
               "writable": writable, "suffix_words": count,
               "writable_words": shell["extent"] - writable,
               "nonzero_words": sum(v != 0 for v in data),
               "binary": str(binary)}
    (result_dir / (label + "-meta-v1426.json")).write_text(
        json.dumps(details, indent=2) + "\n")
    print("CAPTURE %s slot=%d base=%06o vm=%d suffix=%d nonzero=%d" %
          (label, shell["slot"], shell["base"], shell["extent"],
           count, details["nonzero_words"]), flush=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--simh", type=Path, required=True)
    p.add_argument("--boot-ini", type=Path, required=True)
    p.add_argument("--kcore-map", type=Path, required=True)
    p.add_argument("--dsh-map", type=Path, required=True)
    p.add_argument("--dsh-dxr", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--boot-timeout", type=int, default=120)
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    print("Isolating writable media...", flush=True)
    ini, mapping = isolate_media(args.boot_ini, args.output)
    (args.output / "copied-media-v1426.json").write_text(
        json.dumps(mapping, indent=2) + "\n")
    dmap = map_symbols(args.dsh_map)
    kmap = {}
    for line in args.kcore_map.read_text().splitlines():
        fields = line.split()
        if len(fields) == 2 and re.fullmatch(r"[0-7]{1,7}", fields[1]):
            kmap[fields[0]] = int(fields[1], 8)
    payload, image, text_size = read_dxr(args.dsh_dxr)
    console = Console(args.simh, ini, args.output)
    try:
        console.take("LOGIN: ", args.boot_timeout)
        print("Booted guest LOGIN prompt", flush=True)
        console.send("ROOT\r")
        console.take("DSH V1", 80)
        console.take("# ", 70)
        print("Booted real DSH prompt", flush=True)
        console.stop()
        capture(console, "idle_initial", args.output,
                kmap, dmap, payload, image, text_size)
        # GO resumes execution and does not return a SIMH debugger
        # prompt until the next Ctrl-E; do not wait for one here.
        console.send("go\r")
        # Commands must reach and return to a real DSH prompt
        # before a second debugger interrupt is accepted.
        scripts = [
            "SET A1 VALUE1",
            "SET A2 VALUE2",
            "SET A3 VALUE3",
            "SET A4 VALUE4",
            "SET A5 VALUE5",
            "SET A6 VALUE6",
            "ECHO DSH1426COMMANDOK",
        ]
        for cmd in scripts:
            output = console.guest(cmd)
            if cmd.startswith("ECHO") and "DSH1426COMMANDOK" not in output:
                raise ValueError("live DSH command did not complete")
            print("GUEST-CMD " + cmd, flush=True)
        console.stop()
        capture(console, "after_commands", args.output,
                kmap, dmap, payload, image, text_size)
        console.send("go\r")
        output = console.guest("DEF FOO DO ECHO FUNCTIONOK DONE")
        if "DSH: SYNTAX" in output:
            raise ValueError("live DSH rejected function definition")
        output = console.guest("FOO")
        if "FUNCTIONOK" not in output:
            raise ValueError("live DSH function did not execute")
        print("GUEST-FUNCTION FOO", flush=True)
        console.stop()
        capture(console, "after_function", args.output,
                kmap, dmap, payload, image, text_size)
        print("PASS actual PDP-6 DSH read-only snapshots v1426", flush=True)
    finally:
        console.close()


if __name__ == "__main__":
    main()
