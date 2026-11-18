#!/usr/bin/env python3
"""Conserve PDP-6 physical MM words at CTY-barrier RUN/EXIT/WAIT phases.

User virtual PCs overlap fixed KCORE PCs. Plain SIMH breakpoints on
user symbol addresses cannot identify user execution. The test-only
PID1 instead blocks on CTY at phase A/B/C; the host interrupts SIMH,
examines original MM physical words, resumes and releases that phase.
"""

import json
import re
import sys
from pathlib import Path

HALF = (1 << 18) - 1
MAX_EXTENTS = 136
EVENTS = ("v1672_before", "v1672_pressure", "v1672_reaped")
GLOBALS = ("mm_core_words", "mm_extent_capacity", "mm_extent_count",
           "mm_arena_count", "sys_resident_words_immediate")


def lookup(path, symbol):
    source = Path(path).read_text(encoding="ascii")
    matches = re.findall(r"^" + re.escape(symbol) + r"\s+([0-7]+)\s*$",
                         source, re.M)
    if len(matches) != 1:
        raise ValueError("missing/duplicate source-linked symbol " + symbol)
    return int(matches[0], 8)


def observations(content, program):
    for name in EVENTS:
        lookup(program, name)  # Require the actual source-linked test image.
    result = []
    last_end = 0
    for token, name in zip("ABC", EVENTS):
        hold = "V1672 HOLD " + token
        release = "V1672 RELEASE " + token
        if content.count(hold) != 1 or content.count(release) != 1:
            raise ValueError("missing/duplicate guest CTY barrier " + token)
        begin = content.find(hold)
        end = content.find(release, begin)
        if begin < last_end or end < begin:
            raise ValueError("out-of-order guest CTY memory snapshots")
        capture = content[begin + len(hold):end]
        # SIMH may suppress command echo when its console is driven
        # through a PTY. The prompt plus all ORIGINAL physical MM
        # words, checked below, are the actual examination evidence.
        if "sim> " not in capture:
            raise ValueError("SIMH did not pause and inspect MM at " + token)
        words = {}
        for address, value in re.findall(
                r"^(?:sim> )?([0-7]{3,7}):\s+([0-7]{12})\s*$",
                capture, re.M):
            addr = int(address, 8)
            if addr in words:
                raise ValueError("duplicate physical MM word %o" % addr)
            words[addr] = int(value, 8)
        result.append({"name": name, "words": words})
        last_end = end + len(release)
    return result


def read_event(event, addresses, expected_core):
    words = event["words"]

    def physical(addr):
        if addr not in words:
            raise ValueError("missing physical MM word %o" % addr)
        return words[addr]

    def item(name):
        return physical(addresses[name])

    core_words = item("mm_core_words")
    if core_words != expected_core * 1024:
        raise ValueError("SIMH physical core count mismatch")
    capacity = item("mm_extent_capacity")
    if capacity != 4 * (core_words >> 13) + 8 or capacity > MAX_EXTENTS:
        raise ValueError("impossible physical MM descriptor capacity")
    extent_count = item("mm_extent_count")
    arena_count = item("mm_arena_count")
    if not (0 <= extent_count <= capacity) or not (1 <= arena_count <= 3):
        raise ValueError("invalid MM arena or extent count")
    arenas = []
    for i in range(arena_count):
        packed = physical(addresses["mm_arenas"] + i)
        size, base = (packed >> 18) & HALF, packed & HALF
        if size == 0 or base + size > core_words or \
                (arenas and base < arenas[-1][1]):
            raise ValueError("impossible or overlapping MM arenas")
        arenas.append((base, base + size))
    extents = []
    allocated = 0
    by_type = {}
    pins = 0
    pinned_extents = []
    process_aprs = []
    for i in range(extent_count):
        span = physical(addresses["mm_extents"] + 2 * i)
        meta = physical(addresses["mm_extents"] + 2 * i + 1)
        size, base = (span >> 18) & HALF, span & HALF
        kind = (meta >> 18) & 7
        pin_count = (meta >> 21) & 255
        if size <= 0 or kind not in (1, 2, 3, 4) or \
                not any(left <= base and base + size <= right
                        for left, right in arenas) or \
                (extents and base < extents[-1][1]):
            raise ValueError("invalid MM extent bounds/order/owner type")
        extents.append((base, base + size))
        allocated += size
        by_type[str(kind)] = by_type.get(str(kind), 0) + size
        pins += pin_count
        if pin_count:
            pinned_extents.append(dict(base=base, words=size,
                                       kind=kind, owner=meta & HALF,
                                       pins=pin_count))
        if kind == 1:
            process_aprs.append(dict(base=base, words=size,
                                     owner=meta & HALF, pins=pin_count))
    free = 0
    largest = 0
    for start, end in arenas:
        cursor = start
        for left, right in extents:
            if left < start or left >= end:
                continue
            gap = left - cursor
            if gap < 0:
                raise ValueError("overlapping physical MM extent")
            free += gap
            largest = max(largest, gap)
            cursor = right
        gap = end - cursor
        if gap < 0:
            raise ValueError("negative physical MM arena remainder")
        free += gap
        largest = max(largest, gap)
    managed = sum(end - start for start, end in arenas)
    if managed != free + allocated:
        raise ValueError("nonconserved physical MM allocated/free words")
    resident = item("sys_resident_words_immediate") & HALF
    if not 0 < resident < core_words:
        raise ValueError("invalid permanent resident low words")
    return dict(checkpoint=event["name"], physical_core_words=core_words,
                free_words=free, largest_free_words=largest,
                mm_allocated_words=allocated, by_type=by_type,
                process_apr_words=by_type.get("1", 0),
                process_apr_count=len(process_aprs),
                process_aprs=process_aprs,
                pinned_count=pins, pinned_extents=pinned_extents,
                extents=extent_count,
                managed_words=managed, resident_words=resident)


def run(args):
    if len(args) != 6:
        raise ValueError("usage: measure-v1672.py fixture.map kcore.map "
                         "console.log core_kwords report.json")
    fixture, coremap, console, core_text, target = args[1:]
    core = int(core_text)
    content = Path(console).read_text(encoding="ascii", errors="replace")
    for text in ("V1672 START CHILDREN", "V1672 BASELINE",
                 "V1672 PRESSURE", "V1672 REAPED"):
        if text not in content:
            raise ValueError("test user did not reach " + text)
    if any(text in content for text in
           ("V1672 RUN FAILURE", "V1672 WAIT FAILURE",
            "V1672 BAD INITIAL PROCESS", "V1672 MEMINFO FAILURE",
            "SWAP FAIL", "HALT instruction", "INIT: ")):
        raise ValueError("physical test failed before complete user lifecycle")
    if not re.search(r"^MEM\s+%d K\s*$" % core, content, re.M):
        raise ValueError("physical boot used different core size")
    if not re.search(r"^PURE\s+LOADED\s*$", content, re.M):
        raise ValueError("did not install PURE in tested image")
    if "V1672 PASS RUN EXIT WAIT" not in content:
        raise ValueError("child EXIT/WAIT did not complete after last CTY gate")
    addresses = {name: lookup(coremap, name) for name in GLOBALS}
    for name in ("mm_arenas", "mm_extents"):
        addresses[name] = lookup(coremap, name)
    samples = [read_event(event, addresses, core)
               for event in observations(content, fixture)]
    count = 4 if core == 48 else 7
    # Verify SYS_MEMINFO native output against physical MM ownership.
    # This also prevents the VM_SPACE_NONE zombie regression from hiding
    # behind a correct physical extent snapshot.
    field_names = ("TOTAL", "RESIDENT", "PROCESS-WORDS", "PROC-SLOTS")
    reported = {}
    for field in field_names:
        vals = [int(v) for v in re.findall(
            r"^V1672 " + re.escape(field) + r" ([0-9]+)\s*$",
            content, re.M)]
        if len(vals) != 3:
            raise ValueError("missing/duplicate native MEMINFO " + field)
        reported[field] = vals
    for i, sample in enumerate(samples):
        expected_words = (sample["process_apr_words"] +
                          sample["process_apr_count"] * 264)
        if reported["TOTAL"][i] != core * 1024 or \
                reported["RESIDENT"][i] != sample["resident_words"] or \
                reported["PROCESS-WORDS"][i] != expected_words or \
                reported["PROC-SLOTS"][i] != sample["process_apr_count"]+1:
            raise ValueError("native MEMINFO disagrees with actual MM "
                             "process APR/u-area ownership at checkpoint %d" % i)
    if samples[0]["process_apr_count"] != 1 or \
            samples[1]["process_apr_count"] != count + 1 or \
            samples[2]["process_apr_count"] != 1:
        raise ValueError("RUN/WAIT real APR owner count is wrong")
    if samples[0]["pinned_extents"] != samples[1]["pinned_extents"] or \
            samples[0]["pinned_extents"] != samples[2]["pinned_extents"]:
        raise ValueError("baseline MM pin changed or leaked during RUN/WAIT")
    if samples[1]["free_words"] >= samples[0]["free_words"] or \
            samples[2]["free_words"] < samples[1]["free_words"]:
        raise ValueError("physical process pressure/reclaim not observed")
    if any(s["resident_words"] != samples[0]["resident_words"]
           for s in samples):
        raise ValueError("permanent resident low words changed during RUN")
    report = dict(core_kwords=core, children_requested=count,
                  native_meminfo=reported,
                  baseline=samples[0], pressure=samples[1],
                  reaped=samples[2], samples=samples)
    Path(target).write_text(json.dumps(report, indent=2, sort_keys=True)
                            + "\n", encoding="ascii")
    print("PASS v1672 %dK: native RUN %d children, real APR "
          "owners 1->%d->1, free MM %d->%d->%d, largest %d->%d->%d" %
          (core, count, count + 1,
           samples[0]["free_words"], samples[1]["free_words"],
           samples[2]["free_words"],
           samples[0]["largest_free_words"],
           samples[1]["largest_free_words"],
           samples[2]["largest_free_words"]))


if __name__ == "__main__":
    try:
        run(sys.argv)
    except (ValueError, OSError) as exc:
        raise SystemExit("FAIL v1672 physical RUN/WAIT memory: " + str(exc))
