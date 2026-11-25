#!/usr/bin/env python3
"""Read-only physical PURE pressure/FULL replay, with current link addresses."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import select
import subprocess
import time


def symbols(path):
    result = {}
    for line in path.read_text().splitlines():
        fields = line.split()
        if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
            result[fields[0]] = int(fields[1], 8)
    return result


def words(text):
    return {int(a, 8): int(b, 8) for a, b in re.findall(
        r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", text)}


def memory_stage(sym, label, capacity=32):
    out = ["echo V1941_STAGE_" + label]
    for name in ("proc_current_slot", "proc_high_slot", "proc_timer_clock",
                 "mm_extent_count", "mm_extent_capacity", "mm_arena_count",
                 "proc_exec_resv_head_v1933", "proc_swap_service_one",
                 "proc_swap_reclaim"):
        out.append("examine %06o" % sym[name])
    out.append("examine %06o-%06o" % (sym["mm_arenas"],
                                    sym["mm_arenas"] + 7))
    # The 48K profile has a boot-selected capacity of 32 descriptors.
    out.append("examine %06o-%06o" % (sym["mm_extents"],
                                    sym["mm_extents"] + 2*capacity-1))
    out.append("echo V1941_END_" + label)
    return "\n".join(out) + "\n"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("build", type=Path)
    p.add_argument("work", type=Path)
    p.add_argument("prefix", type=Path)
    p.add_argument("--timeout", type=int, default=1150)
    p.add_argument("--children", type=int, choices=(5, 6), required=True)
    args = p.parse_args()
    b, w, prefix = (x.resolve() for x in
                    (args.build, args.work, args.prefix))
    w.mkdir(parents=True, exist_ok=True)
    media = w / "media"
    media.mkdir()
    sym = symbols(b / "kcore.map")
    mres = symbols(b / "pure-mres-v1612.map")
    full_off = mres["exec_image_full_bounded_v1391"]
    service_off = mres["proc_pure_mres_service_v1612"]
    reclaim_off = mres["proc_pure_mres_reclaim_v1612"]
    dxr = subprocess.check_output(
        [str(prefix / "bin/dxrcheck"), "-d",
         str(b / "pure-mres-v1612.dxr")], text=True)
    full_opcode = int(re.search(
        r"(?m)^IMAGE  %06o ([0-7]{12})$" % full_off, dxr).group(1), 8)
    for line in dxr.splitlines():
        if line.startswith("RELOC "):
            assert "%06o" % full_off not in line.split()[3:], (
                "FULL entry needs relocation-aware opcode verification")
    (w / "images.sha256").write_text("".join(
        hashlib.sha256((b / name).read_bytes()).hexdigest() + "  " + name + "\n"
        for name in ("kcore.dxr", "pure-mres-v1612.dxr",
                     "kinit.lowmem.words")))
    source = (b / "boot.ini").read_text()
    assert source.count("set cpu 48k\n") == 1
    lines = []
    units = set()
    for line in source.splitlines():
        if line.startswith("attach -q "):
            f = line.split()
            dev = f[2]
            if dev.startswith(("dsk", "dr")):
                continue
            if dev.startswith(("dtc", "mtc")):
                dst = media / (dev + ".tap")
                dst.write_bytes(Path(f[3]).read_bytes())
                line = "attach -q " + dev + " " + str(dst)
                units.add(dev)
        if line.startswith("attach -q -n "):
            f = line.split()
            assert len(f) == 5
            line = "attach -q -n " + f[3] + " " + str(media / (f[3]+".out"))
        if line.startswith("set -q -n log "):
            line = "set -q -n log " + str(w / "simh.log")
        lines.append(line)
    assert {"dtc0", "dtc1", "dtc2", "dtc3"} <= units
    source = "\n".join(lines) + "\n"
    assert source.count("go 020\nexit\n") == 1
    marker = "a"*args.children + "x[B"
    first = ('expect "%s"\ngo 020\n' % marker +
             memory_stage(sym, "B"))
    (w / "physical.ini").write_text(
        source.replace("go 020\nexit\n", first))
    helper = Path(__file__).resolve().parents[2] / "lib/daimos-simh-headless.sh"
    port = 38000 + os.getpid() % 9000
    subprocess.run(["sh", str(helper), str(w / "physical.ini"),
                    str(w / "headless.ini"), str(port), str(port+12000)],
                   check=True)
    deadline = time.monotonic() + args.timeout
    proc = subprocess.Popen(
        ["stdbuf", "-o0", "-e0", str(prefix / "bin/pdp6"),
         str(w / "headless.ini")], stdin=subprocess.PIPE,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=b,
        env=dict(os.environ, TERM="dumb"), bufsize=0)
    output = bytearray()
    with (w / "physical.log").open("wb", buffering=0) as log:
        def wait_for(marker, start):
            target = marker.encode()
            while target not in output[start:]:
                if time.monotonic() >= deadline:
                    raise RuntimeError("physical timeout before " + marker)
                if not select.select([proc.stdout], [], [], 0.5)[0]:
                    continue
                data = os.read(proc.stdout.fileno(), 65536)
                if not data:
                    raise RuntimeError("simulator exited before " + marker)
                log.write(data)
                output.extend(data)
                if len(output) > 4000000:
                    raise RuntimeError("oversized monitor transcript")
            return output[start:].decode("ascii", "replace").replace("\r", "")

        def send(cmd):
            start = len(output)
            proc.stdin.write(cmd.encode("ascii"))
            proc.stdin.flush()
            return start

        try:
            trace = wait_for("V1941_END_B", 0)
            assert marker in trace, "pressure workload did not reach B"
            snap = words(trace.split("V1941_STAGE_B", 1)[1])
            capacity = snap[sym["mm_extent_capacity"]]
            assert 0 < snap[sym["mm_extent_count"]] <= capacity == 32
            service = snap[sym["proc_swap_service_one"]]
            reclaim = snap[sym["proc_swap_reclaim"]]
            assert service >> 18 == reclaim >> 18 == 0o254000
            base = (service & 0o777777) - service_off
            assert base > 0 and (reclaim & 0o777777) == base + reclaim_off
            full = base + full_off
            (w / "binding.txt").write_text(
                "base=%06o full=%06o opcode=%012o\n" %
                (base, full, full_opcode))
            print("v1941 physical PURE base %06o FULL %06o" %
                  (base, full), flush=True)
            start = send('expect "[A"\ncont\n' +
                         memory_stage(sym, "A"))
            wait_for("V1941_END_A", start)
            # Confirm executable instruction in the installed MRES
            # before arming a breakpoint, not an old absolute address.
            start = send("examine %06o\necho V1941_OPCODE_END\n" % full)
            actual = words(wait_for("V1941_OPCODE_END", start))
            assert actual[full] == full_opcode
            start = send("break %06o\ncont\necho V1941_FULL_ENTRY\n" % full +
                         "examine 1-4\n" + memory_stage(sym, "FULL"))
            trace = wait_for("V1941_END_FULL", start)
            assert re.search(r"Breakpoint, PC: %06o\b" % full, trace)
            print("v1941 original FULL callback reached", flush=True)
            start = send('nobreak all\nexpect "Z"\ncont\n' +
                         memory_stage(sym, "Z") + "cont\nexit\n")
            wait_for("HALT instruction", start)
            wait_for("Goodbye", start)
            assert proc.wait(timeout=10) == 0
        finally:
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
            while select.select([proc.stdout], [], [], 0)[0]:
                data = os.read(proc.stdout.fileno(), 65536)
                if not data:
                    break
                log.write(data)
                output.extend(data)
            (w / "physical.clean").write_bytes(
                bytes(output).replace(b"\r", b""))
    print("v1941 physical monitor replay completed: " + str(w))


if __name__ == "__main__":
    main()
