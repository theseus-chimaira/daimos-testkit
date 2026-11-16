#!/usr/bin/env python3
"""Attribute a real PDP-6 interrupted PC to its installed MRES module.

Only preserved guest examinations, linked maps, and an actual linked tape
DXR image are admissible. This does not classify tape progress or OOM.
"""
import re
import subprocess
import sys
from pathlib import Path

ADDR_MASK = 0o777777
JRST_OPCODE = 0o254000000000
SKIPN_OPCODE = 0o336000000000


def symbols(path):
    result = {}
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if len(fields) >= 2 and not fields[1].strip("01234567"):
            result[fields[0]] = int(fields[1], 8)
    return result


def examined(trace):
    return {int(a, 8): int(v, 8) for a, v in re.findall(
        r"(?m)(?<![0-7])([0-7]{4,7}):\s*([0-7]{1,12})(?=\s|$)",
        trace)}


def dxr_image(path, dxrcheck):
    result = subprocess.run([dxrcheck, "-d", str(path)],
                            check=True, capture_output=True, text=True)
    image = {int(a, 8): int(v, 8) for a, v in re.findall(
        r"(?m)^IMAGE\s+([0-7]{6})\s+([0-7]{12})$", result.stdout)}
    header = re.search(r"image=([0-7]+)", result.stdout)
    if not header:
        raise ValueError("DXR image header missing")
    return image, int(header.group(1), 8)


def audit(kmap, pmap, tape_dxr, service_trace, interrupted_trace,
          source, dxrcheck):
    kernel = symbols(kmap)
    pure = symbols(pmap)
    for name in ("proc_swap_reclaim", "proc_swap_service_one",
                 "storage_count"):
        if name not in kernel:
            raise ValueError("missing fixed KCORE symbol: " + name)
    for name in ("proc_pure_mres_reclaim_v1612",
                 "proc_pure_mres_service_v1612"):
        if name not in pure:
            raise ValueError("missing linked PURE MRES export: " + name)
    text = Path(service_trace).read_text()
    if ("PURE" not in text or "LOADED" not in text or
            "<010000+020000>" not in text):
        raise ValueError("probe is not a source-matched physical PURE boot")
    resident = examined(text)
    bases = []
    for word_name, export_name in (
            ("proc_swap_reclaim", "proc_pure_mres_reclaim_v1612"),
            ("proc_swap_service_one", "proc_pure_mres_service_v1612")):
        address = kernel[word_name]
        if address not in resident:
            raise ValueError("missing physical scheduler trampoline")
        instruction = resident[address]
        if instruction & ~ADDR_MASK != JRST_OPCODE:
            raise ValueError("scheduler trampoline is not JRST")
        bases.append((instruction & ADDR_MASK) - pure[export_name])
    if bases[0] != bases[1] or bases[0] != 0o32027:
        raise ValueError("two PURE exports disagree on installed base")
    pure_base = bases[0]

    late = Path(interrupted_trace).read_text()
    match = re.search(r"SIGTERM received, PC:\s*([0-7]{6})", late)
    if not match:
        raise ValueError("late CPU snapshot is not an interrupted PC")
    pc = int(match.group(1), 8)
    if pc not in examined(text):
        raise ValueError("probe did not examine the interrupted instruction")
    instruction = examined(text)[pc]
    expected = SKIPN_OPCODE | kernel["storage_count"]
    if instruction != expected:
        raise ValueError("interrupted opcode is not SKIPN storage_count")
    if pc >= pure_base:
        raise ValueError("interrupted PC is not below PURE module")

    tape, image_words = dxr_image(tape_dxr, dxrcheck)
    matches = [offset for offset, value in tape.items()
               if value == expected]
    if len(matches) != 1:
        raise ValueError("not exactly one matching linked tape instruction")
    tape_offset = matches[0]
    tape_base = pc - tape_offset
    if (tape_base != 0o30431 or
            tape_base + image_words > pure_base or
            not (tape_base <= pc < tape_base + image_words)):
        raise ValueError("invalid tape module relocation/overlap")
    asm = Path(source).read_text()
    if not re.search(
            r"dtc_search_state_ok:.*?\bskipn storage_count\b",
            asm, re.S):
        raise ValueError("source does not identify the DECtape search wait")
    print("PASS v1617 physical PURE MRES base=%06o" % pure_base)
    print("PASS v1617 physical tape MRES base=%06o" % tape_base)
    print("PASS v1617 interrupted PC=%06o tape image offset=%06o" %
          (pc, tape_offset))
    print("PASS v1617 source-linked SKIPN storage_count=%06o" %
          kernel["storage_count"])
    print("OPEN v1617: tape search progress, slot-0 restoration, BRK return")


def audit_wait(kmap, tape_source, wait_trace, tape_dxr, dxrcheck):
    """Check the preserved v1617 physical DTC breakpoint and linked image.

    v1618 legitimately raises the source timeout to 120 seconds. The old
    physical evidence remains tied to its exact v1617 45-second DXR,
    not to the timeout selected by a newer source checkout.
    """
    kernel = symbols(kmap)
    required = ("storage_state", "storage_count", "proc_current_slot",
                "mm_extent_count", "mm_extents")
    if any(name not in kernel for name in required):
        raise ValueError("incomplete physical MM/storage source map")
    trace = Path(wait_trace).read_text()
    if "Breakpoint, PC: 030762 " not in trace:
        raise ValueError("real DECtape wait breakpoint was not reached")
    memory = examined(trace)

    def word(name):
        if kernel[name] not in memory:
            raise ValueError("missing physical state word: " + name)
        return memory[kernel[name]]

    if word("storage_state") != 0o200:
        raise ValueError("DECtape was not in the RBN search state")
    if word("storage_count") != 0o777777772564:
        raise ValueError("45-second search countdown not initialized")
    if word("proc_current_slot") != 0:
        raise ValueError("search did not execute on kernel idle slot 0")
    asm = Path(tape_source).read_text()
    if not re.search(r"\.set DTC_SEARCH_TIMEOUT_TICKS,[0-7]+\b", asm):
        raise ValueError("DECtape search timeout source definition missing")
    image, unused_size = dxr_image(tape_dxr, dxrcheck)
    if (image.get(0o343) != 0o561200772564 or
            image.get(0o405) != 0o561100772564):
        raise ValueError("v1617 physical evidence is not from its 45s DXR")
    if word("mm_extent_count") > 136:
        raise ValueError("invalid physical MM extent count")
    packed = {}
    present = []
    for i in range(word("mm_extent_count")):
        address = kernel["mm_extents"] + 2 * i
        if address not in memory or address + 1 not in memory:
            raise ValueError("missing physical MM descriptor")
        span = memory[address]
        meta = memory[address + 1]
        kind = (meta >> 18) & 0o7
        owner = meta & 0o777777
        base = span & 0o777777
        length = (span >> 18) & 0o777777
        pins = (meta >> 21) & 0o377
        if kind == 1:
            raise ValueError("unexpected runnable PROCESS at tape wait")
        if kind == 4:
            if owner in packed:
                raise ValueError("duplicate PACKED process extent")
            packed[owner] = (base, length, pins)
        present.append((base, base + length))
    present.sort()
    for i in range(1, len(present)):
        if present[i - 1][1] > present[i][0]:
            raise ValueError("overlapping physical owner descriptors")
    expected = {
        5: (0o67000, 0o7000, 0),
        4: (0o77000, 0o7000, 0),
        3: (0o107000, 0o7000, 0),
        2: (0o116000, 0o10000, 1),
    }
    if packed != expected:
        raise ValueError("unexpected real RAW suffix/claimed-prefix owners")
    print("PASS v1617 physical DECtape: active RBN search, -05214 ticks")
    print("PASS v1617 physical MM: three 007000-word RAW suffixes,")
    print("  one pinned 010000-word PACKED prefix claim, slot 0")
    print("OPEN v1617: clock countdown progress, VFS completion, RUN/WAIT")


def main():
    if len(sys.argv) not in (8, 9):
        raise ValueError(
            "usage: audit-module-origin-v1617.py KCORE.map PURE.map "
            "TAPE.dxr PROBE.clean INTERRUPTED.clean TAPE.s DXRCHECK "
            "[WAIT.clean]")
    audit(*sys.argv[1:8])
    if len(sys.argv) == 9:
        audit_wait(sys.argv[1], sys.argv[6], sys.argv[8],
                   sys.argv[3], sys.argv[7])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit("FAIL v1617 module attribution: " + str(error))
