#!/usr/bin/env python3
"""Read-only v1983 directory bitmap or matched RAW pressure witnesses."""
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
    # Capture the complete boot-selected MM descriptor table.
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
    p.add_argument("--raw", action="store_true", help="matched RAW pressure and reaping control")
    p.add_argument("--core", type=int, choices=(48, 64), default=64)
    args = p.parse_args()
    b, w, prefix = (x.resolve() for x in
                    (args.build, args.work, args.prefix))
    w.mkdir(parents=True, exist_ok=True)
    media = w / "media"
    media.mkdir()
    sym = symbols(b / "kcore.map")
    mres = symbols(b / "pure-mres-v1612.map")
    full_off = mres["proc_pure_ram_restore_v1391" if args.raw else "proc_pure_bitmap_restore_v1980"]
    finish_off = mres.get("mm_pure_bitmap_finish_v1664")
    terminal_off = mres["pdp6_pure_detach_v1609" if args.raw else "proc_pure_term_v1982"]
    assert (finish_off is None) == args.raw
    service_off = mres["proc_pure_mres_service_v1612"]
    reclaim_off = mres["proc_pure_mres_reclaim_v1612"]
    dxr = subprocess.check_output(
        [str(prefix / "bin/dxrcheck"), "-d",
         str(b / "pure-mres-v1612.dxr")], text=True)
    full_opcode = int(re.search(
        r"(?m)^IMAGE  %06o ([0-7]{12})$" % full_off, dxr).group(1), 8)
    full_reloc = any("%06o" % full_off in line.split()[3:]
                     for line in dxr.splitlines() if line.startswith("RELOC "))
    (w / "images.sha256").write_text("".join(
        hashlib.sha256((b / name).read_bytes()).hexdigest() + "  " + name + "\n"
        for name in ("kcore.dxr", "pure-mres-v1612.dxr",
                     "kinit.lowmem.words")))
    source = (b / "boot.ini").read_text()
    assert source.count("set cpu %dk\n" % args.core) == 1
    capacity = 4 * (args.core // 8) + 8
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
    marker = "x[B"
    first = ('expect "%s"\ngo 020\n' % marker +
             memory_stage(sym, "B", capacity))
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
            admitted = re.search(r"(a{4,12})x\[B", trace)
            assert admitted, "pressure workload did not reach B with admitted children"
            children = len(admitted.group(1))
            snap = words(trace.split("V1941_STAGE_B", 1)[1])
            capacity = snap[sym["mm_extent_capacity"]]
            assert 0 < snap[sym["mm_extent_count"]] <= capacity == 4 * (args.core // 8) + 8
            service = snap[sym["proc_swap_service_one"]]
            reclaim = snap[sym["proc_swap_reclaim"]]
            assert service >> 18 == reclaim >> 18 == 0o254000
            base = (service & 0o777777) - service_off
            assert base > 0 and (reclaim & 0o777777) == base + reclaim_off
            full = base + full_off
            (w / "binding.txt").write_text(
                "base=%06o full=%06o opcode=%012o\n" %
                (base, full, full_opcode))
            assert (snap[sym["proc_swap_service_one"]] & 0o777777) == base+service_off
            def examine(ranges, label):
                cmd = "".join("examine %06o-%06o\n" % (lo, hi) for lo,hi in ranges)
                start = send(cmd + "echo " + label + "\n")
                return words(wait_for(label,start))
            rt = sym["proc_storage_runtime_v29"]
            meta = examine([(rt,rt+1),(sym["proc_table"],sym["proc_table"]),(sym["proc_swap_term_v1666"],sym["proc_swap_term_v1666"])],"V1983_META")
            modebase,nslots = meta[rt],meta[rt+1]
            table = meta[sym["proc_table"]]
            assert 0<modebase<65536 and 0<nslots<=255 and 0<table<65536
            assert meta[sym["proc_swap_term_v1666"]] == (0o254000<<18)|(base+terminal_off)
            def snapshot(label):
                start = send(memory_stage(sym,label,capacity))
                mm = words(wait_for("V1941_END_"+label,start))
                mm.update(examine([(modebase,modebase+(nslots+17)//18-1),(table,table+3*nslots-1)],"V1983_MAP_"+label))
                return mm
            def owners(m,slot):
                return [(m[sym["mm_extents"]+2*i]&0o777777,m[sym["mm_extents"]+2*i]>>18,(m[sym["mm_extents"]+2*i+1]>>18)&7,(m[sym["mm_extents"]+2*i+1]>>21)&255) for i in range(m[sym["mm_extent_count"]]) if m[sym["mm_extents"]+2*i+1]&0o777777==slot and (m[sym["mm_extents"]+2*i+1]>>18)&7 in (1,4)]
            def mode(m,slot):
                return (m[modebase+slot//18]>>(2*(slot%18)))&3
            m=snapshot("PRESSURE")
            packed=[slot for slot in range(1,nslots) if mode(m,slot)==3]
            raw=[slot for slot in range(1,nslots) if mode(m,slot)==2]
            print("v1983 installed PURE %06o, mode3=%s mode2=%s"%(base,packed,raw),flush=True)
            assert (raw and not packed) if args.raw else bool(packed), "wrong representation at pressure checkpoint"
            for slot in packed+raw:
                own=owners(m,slot)
                assert len(own)==1 and own[0][2:]==(4,0)
                vm=m[table+3*slot+1]
                assert vm&0o777777==0 and 0<own[0][1]<vm>>18
                assert own[0][0]%(1024 if slot in packed and "mm_pure_bitmap_place_v1985" not in mres else 128)==0
                print("v1983 slot=%d mode=%d retained=%d full=%d"%(slot,mode(m,slot),own[0][1],vm>>18),flush=True)
            if args.raw:
                # No requirement that RAW uses disjoint FULL: PREFIX is legal.
                print("RAW pressure checkpoint verified; continuing to exact WAIT/EXIT",flush=True)
            else:
                actual=examine([(full,full)],"V1983_OPCODE")
                expected = full_opcode
                if full_reloc:
                    expected = (full_opcode & ~0o777777) | ((full_opcode+base)&0o777777)
                assert actual[full]==expected
                start=send("break %06o\ncont\necho V1983_RESTORE\nexamine 1-4\necho V1983_AC\n"%full)
                trace=wait_for("V1983_AC",start)
                assert re.search(r"Breakpoint, PC: %06o\b"%full,trace)
                slot=words(trace)[1]
                m=snapshot("RESTORE")
                assert m[sym["proc_current_slot"]]==0 and mode(m,slot)==3
                own=owners(m,slot)
                assert len(own)==1 and own[0][2:]==(4,0)
                print("v1983 actual mode3 restore entered slot=%d"%slot,flush=True)
                finish=base+finish_off
                start=send("nobreak all\nbreak %06o\ncont\necho V1983_FINISH\nexamine 1-4\necho V1983_FINISH_AC\n"%finish)
                trace=wait_for("V1983_FINISH_AC",start)
                assert re.search(r"Breakpoint, PC: %06o\b"%finish,trace)
                ac=words(trace); slot,source,encoded,target=(ac[i] for i in (1,2,3,4))
                m=snapshot("FINISH")
                own=owners(m,slot)
                assert mode(m,slot)==3 and m[sym["proc_current_slot"]]==0
                assert (source,encoded,4,1) in own and len(own)==2
                fullowner=[v for v in own if v[2]==1][0]
                assert fullowner[0]==target and fullowner[3]==1
                print("v1983 actual atomic finish: slot=%d source=%06o/%d target=%06o/%d"%(slot,source,encoded,target,fullowner[1]),flush=True)
            start=send('nobreak all\nexpect "Z"\ncont\necho V1983_Z_STOP\n')
            tail=wait_for("V1983_Z_STOP",start)
            # SIMH ECHO may concatenate directly to guest output.
            # Accept only the guest Z immediately preceding this stop,
            # not a Z found in a command, address or monitor label.
            prefix = (r"[0-7]{6}/[0-7]{6}\]<[0-7]{6}\+[0-7]{6}>"
                      r"\[A[0-7]{6}/[0-7]{6}\]\{[0-7]{6}-[0-7]{6}\}L"
                      if args.raw else "")
            count = "w{%d}" % children if args.raw else "w+"
            assert re.search(r"(?m)^"+prefix+count+r"Z[ \t\n]*V1983_Z_STOP",tail), "no guest completion marker"
            assert "HALT instruction" not in tail
            m=snapshot("Z")
            # Parent emits Z only after every admitted child's exact PID,
            # sparse data check and expected exit status has passed. All
            # children must have retired their owners and storage cells.
            assert m[sym["proc_current_slot"]]==1
            for child in range(2,nslots):
                assert mode(m,child)==0 and not owners(m,child)
                assert m[table+3*child+2]>>33==0
            start=send("cont\nexit\n")
            wait_for("HALT instruction",start)
            wait_for("Goodbye",start)
            assert proc.wait(timeout=10)==0
            print("PASS physical %s and %d checked WAIT/EXIT"%("RAW" if args.raw else "mode3 ownership/restore",children),flush=True)
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
    print("v1983 physical monitor replay completed: " + str(w))


if __name__ == "__main__":
    main()
