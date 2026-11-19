#!/usr/bin/env python3
"""Audit successive real PDP-6 Type-551 search observations.

Only read actual SIMH core examinations, the matching fixed KCORE map,
the linked TAPE DXR and the original tape/clock source. Do not infer
restoration success or unobserved completion of the RBN search.
"""
import re
import subprocess
import sys
from pathlib import Path

WORD_MASK = (1 << 36) - 1


def source_symbols(path):
    found = {}
    for line in Path(path).read_text().splitlines():
        parts = line.split()
        if len(parts) >= 2 and not parts[1].strip("01234567"):
            found[parts[0]] = int(parts[1], 8)
    return found


def memory_samples(text, address):
    pattern = r"(?m)(?<![0-7])%o:\s*([0-7]{12})(?=\s|$)" % address
    return [int(w, 8) for w in re.findall(pattern, text)]


def load_tape_image(path, dxrcheck):
    proc = subprocess.run([dxrcheck, "-d", path], text=True,
                          capture_output=True, check=True)
    header = re.search(
        r"\bimage=([0-7]+)\s+bss=([0-7]+)\b", proc.stdout)
    if not header:
        raise ValueError("linked tape DXR lacks image/BSS header")
    words = {int(a, 8): int(w, 8) for a, w in re.findall(
        r"(?m)^IMAGE\s+([0-7]{6})\s+([0-7]{12})$", proc.stdout)}
    if (words.get(0o343) != 0o561200761740 or
            words.get(0o405) != 0o561100761740):
        raise ValueError("both compiled DECtape timeout rearms must be 120s")
    return int(header.group(1), 8), int(header.group(2), 8)


def audit(kmap, tape_dxr, tape_src, clock_src, trace_path, dxrcheck):
    sym = source_symbols(kmap)
    for name in ("storage_state", "storage_count", "clk_tick_count"):
        if name not in sym:
            raise ValueError("missing fixed KCORE source symbol " + name)
    text = Path(trace_path).read_text()
    if ("Breakpoint, PC: 030762 " not in text or
            "PURE" not in text or "LOADED" not in text or
            "<010000+020000>" not in text):
        raise ValueError("missing genuine opt-in PURE search breakpoint")
    if "Step expired, PC:" not in text:
        raise ValueError("SIMH timed execution did not reach a step limit")

    image, bss = load_tape_image(tape_dxr, dxrcheck)
    if (image, bss) != (0o607, 0o17):
        raise ValueError("physical tape BSS offset/size changed")
    base = 0o30431 + image
    if base != 0o31240:
        raise ValueError("incorrect installed tape BSS address")
    tape_source = Path(tape_src).read_text()
    clock_source = Path(clock_src).read_text()
    layout = re.findall(
        r"(?m)^\s*(dtc_request_\w+|dtc_target_block|"
        r"dtc_search_retries|dtc_last_mark|tape_transfer_event|"
        r"dtc_motion):\s*\.block\s+(1|010)\b",
        tape_source)
    expected_layout = [
        ("dtc_request_unit", "1"), ("dtc_request_write", "1"),
        ("dtc_request_reverse", "1"), ("dtc_target_block", "1"),
        ("dtc_search_retries", "1"), ("dtc_last_mark", "1"),
        ("tape_transfer_event", "1"), ("dtc_motion", "010"),
    ]
    if layout != expected_layout:
        raise ValueError("original tape BSS variable order changed")
    if not re.search(
            r"\.set DTC_SEARCH_TIMEOUT_TICKS,016040\b", tape_source):
        raise ValueError("v1618 120-second DECtape search timeout changed")
    if not re.search(
            r"\.set MTC_CONTROL_TIMEOUT_TICKS,0151440\b", tape_source):
        raise ValueError("original 15-minute MTC rewind bound changed")
    if not re.search(
            r"dtc_search_pi_continue:.*?movem 2,storage_count",
            tape_source, re.S):
        raise ValueError("PI3 block mark timer rearm source missing")
    if not re.search(
            r"storage_clock_tick:\s*skipge storage_count\s*"
            r"aos storage_count", clock_source):
        raise ValueError("line-clock timeout aging source missing")

    state = memory_samples(text, sym["storage_state"])
    count = memory_samples(text, sym["storage_count"])
    ticks = memory_samples(text, sym["clk_tick_count"])
    reverse = memory_samples(text, base + 2)
    target = memory_samples(text, base + 3)
    retries = memory_samples(text, base + 4)
    marks = memory_samples(text, base + 5)
    sample_count = len(ticks)
    if not (2 <= sample_count <= 4 and
            all(len(x) == sample_count for x in
                (state, count, reverse, target, retries, marks))):
        raise ValueError("incomplete timed same-guest snapshots")
    if len(re.findall(r"Step expired, PC:", text)) < sample_count - 1:
        raise ValueError("SIMH timed steps did not finish")
    if (state[0] != 0o200 or
            count[0] != 0o777777761740 or
            target[0] != 4 or retries[0] != 7 or
            reverse[0] != 0o10000):
        raise ValueError("first DECtape state is not an armed RBN search")
    deltas = [(ticks[i] - ticks[i - 1]) & WORD_MASK
              for i in range(1, sample_count)]
    if any(n >= 10000 for n in deltas) or sum(deltas) == 0:
        raise ValueError("no bounded physical line-clock progression")
    if all(mark == marks[0] for mark in marks[1:]):
        raise ValueError("no physical PI3 block-mark progression")
    print("PASS v1618 physical %d consecutive DECtape samples" %
          sample_count)
    print("PASS v1618 120s 60-Hz search limit, both native rearm paths")
    for i in range(sample_count):
        print("  sample %d: clk=%06o state=%06o count=%012o "
              "mark=%04o target=%04o retries=%o" %
              (i, ticks[i], state[i], count[i],
               marks[i], target[i], retries[i]))
    print("PASS v1618 line-clock increments: %s" %
          ", ".join(str(n) for n in deltas))
    print("PASS v1618 PI3 tape block mark changed in one real guest")
    print("OPEN v1618: VFS completion, prefix commit/rollback, RUN/WAIT")


def main():
    if len(sys.argv) != 7:
        raise ValueError(
            "usage: audit-timer-v1618.py KCORE.map TAPE.dxr "
            "TAPE.s STORAGE_ROUTER.s TRACE.clean DXRCHECK")
    audit(*sys.argv[1:])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        raise SystemExit("FAIL v1618 timer audit: " + str(exc))
