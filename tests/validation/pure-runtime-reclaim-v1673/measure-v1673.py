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
EVENTS = ("v1673_before", "v1673_pressure", "v1673_reaped")
GLOBALS = ("mm_core_words", "mm_extent_capacity", "mm_extent_count",
           "mm_arena_count", "sys_resident_words_immediate",
           "proc_table", "proc_high_slot", "proc_swap_records",
           "proc_storage_runtime_v29")


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
        hold = "V1673 HOLD " + token
        release = "V1673 RELEASE " + token
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
    packed_aprs = []
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
        if kind == 4:
            packed_aprs.append(dict(base=base, words=size,
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
    # Source-linked *physical* process table, one-word backing record and
    # two-bit mode map must agree with actual MM_TYPE_PROCESS/PACKED_PROCESS
    # owners. The reader examines the original arrays; no kernel probe exists.
    table = item("proc_table")
    high = item("proc_high_slot")
    records = item("proc_swap_records")
    storage = item("proc_storage_runtime_v29")
    slots = physical(addresses["proc_storage_runtime_v29"] + 1)
    if not (0 < table and 0 < records and 0 < storage and
            1 < high <= slots <= 64 and
            slots == min(64, 2 * (core_words >> 13)) and
            table + 3 * high <= core_words and
            records + high <= core_words and
            storage + (high + 17) // 18 <= core_words):
        raise ValueError("invalid physical process/mode allocation")
    processes = []
    free_slots = []
    physical_owners = {e["owner"]: e for e in process_aprs + packed_aprs}
    if len(physical_owners) != len(process_aprs) + len(packed_aprs):
        raise ValueError("duplicate resident/packed physical owner")
    for slot in range(high):
        meta = physical(table + slot * 3)
        vm = physical(table + slot * 3 + 1)
        sched = physical(table + slot * 3 + 2)
        backing = physical(records + slot)
        mode_word = physical(storage + slot // 18)
        mode = (mode_word >> (2 * (slot % 18))) & 3
        state = (sched >> 33) & 7
        vm_words = (vm >> 18) & HALF
        vm_base = vm & HALF
        owner = physical_owners.get(slot)
        if slot == 0:
            # The kernel idle/swapper slot is SRUN without a user APR
            # or a stable user u-area. It is not a user allocation.
            if state != 2 or mode != 0 or vm or meta or owner is not None:
                raise ValueError("invalid kernel slot0 state")
            continue
        if not state:
            if mode != 0 or owner is not None:
                raise ValueError("free process has live storage/MM owner")
            free_slots.append(slot)
            continue
        if state == 4:
            raise ValueError("unexpected slot0/zombie at stable guest gate")
        if (meta & 0o400000) == 0 or (meta >> 18) == 0 or \
                not vm_words or owner is None or owner["pins"]:
            raise ValueError("missing stable u-area or process MM owner")
        saved_backing = physical(((meta >> 18) & HALF) + 0o406)
        if mode == 0:
            if owner not in process_aprs or vm_base != owner["base"] or \
                    vm_words != owner["words"] or saved_backing:
                raise ValueError("resident process and APR disagree")
        elif mode == 2:
            text = (backing >> 22) & 0o37777
            prefix = (text + 16) & ~127
            if owner not in packed_aprs or vm_base != 0 or \
                    not (0 < prefix < vm_words) or \
                    owner["words"] != vm_words - prefix or \
                    saved_backing != backing or \
                    state not in (3, 6):
                raise ValueError("RAW PURE PACKED mode/owner/backing mismatch")
        else:
            raise ValueError("unexpected DISK/bitmap mode on swapless guest")
        processes.append(dict(slot=slot, state=state, storage_mode=mode,
                              vm_words=vm_words, vm_base=vm_base,
                              backing=backing,
                              saved_backing=saved_backing, physical=owner))
    if len(processes) != len(physical_owners) or \
            not any(p["slot"] == 1 for p in processes):
        raise ValueError("unaccounted process APR or PACKED owner")
    return dict(checkpoint=event["name"], physical_core_words=core_words,
                free_words=free, largest_free_words=largest,
                mm_allocated_words=allocated, by_type=by_type,
                process_apr_words=by_type.get("1", 0),
                process_apr_count=len(process_aprs),
                process_aprs=process_aprs,
                packed_aprs=packed_aprs, packed_apr_count=len(packed_aprs),
                process_states=processes,
                free_process_slots=free_slots,
                process_capacity=slots, process_high_slot=high,
                logical_process_words=sum(p["vm_words"] + 264
                                          for p in processes),
                resident_process_words=(sum(p["physical"]["words"]
                                             for p in processes
                                             if p["storage_mode"] == 0) +
                                        len(processes) * 264),
                pinned_count=pins, pinned_extents=pinned_extents,
                extents=extent_count,
                managed_words=managed, resident_words=resident)


def run(args):
    if len(args) != 6:
        raise ValueError("usage: measure-v1673.py fixture.map kcore.map "
                         "console.log core_kwords report.json")
    fixture, coremap, console, core_text, target = args[1:]
    core = int(core_text)
    content = Path(console).read_text(encoding="ascii", errors="replace")
    for text in ("V1673 START CHILDREN", "V1673 BASELINE",
                 "V1673 PRESSURE", "V1673 REAPED"):
        if text not in content:
            raise ValueError("test user did not reach " + text)
    if any(text in content for text in
           ("V1673 RUN FAILURE", "V1673 WAIT FAILURE",
            "V1673 BAD INITIAL PROCESS", "V1673 MEMINFO FAILURE",
            "V1673 UNEXPECTED TRIGGER ADMISSION",
            "SWAP FAIL", "HALT instruction", "INIT: ")):
        raise ValueError("physical test failed before complete user lifecycle")
    if content.count("V1673 TRIGGER REFUSED") != 1 or \
            content.count("V1673 TRIGGER RUN 9") != 1:
        raise ValueError("no single genuine refused pressure RUN")
    if not re.search(r"^MEM\s+%d K\s*$" % core, content, re.M):
        raise ValueError("physical boot used different core size")
    if not re.search(r"^PURE\s+LOADED\s*$", content, re.M):
        raise ValueError("did not install PURE in tested image")
    if "V1673 PASS RUN EXIT WAIT" not in content:
        raise ValueError("child EXIT/WAIT did not complete after last CTY gate")
    addresses = {name: lookup(coremap, name) for name in GLOBALS}
    for name in ("mm_arenas", "mm_extents"):
        addresses[name] = lookup(coremap, name)
    samples = [read_event(event, addresses, core)
               for event in observations(content, fixture)]
    if core != 48:
        raise ValueError("v1673 native RAW restore acceptance is 48K only")
    count = 9
    # Verify SYS_MEMINFO native output against physical MM ownership.
    # This also prevents the VM_SPACE_NONE zombie regression from hiding
    # behind a correct physical extent snapshot.
    field_names = ("TOTAL", "RESIDENT", "PROCESS-WORDS", "PROC-SLOTS")
    reported = {}
    for field in field_names:
        vals = [int(v) for v in re.findall(
            r"^V1673 " + re.escape(field) + r" ([0-9]+)\s*$",
            content, re.M)]
        if len(vals) != 3:
            raise ValueError("missing/duplicate native MEMINFO " + field)
        reported[field] = vals
    for i, sample in enumerate(samples):
        # SYS_MEMINFO deliberately counts allocated resident VM and
        # all stable u-areas. A PACKED RAW process retains physical
        # suffix words in MM_TYPE_PACKED_PROCESS, not a runnable APR;
        # those suffixes must NOT appear in process_words. The logical
        # VM size remains authoritative in the process table and is
        # separately proved for every packed owner above.
        expected_words = sample["resident_process_words"]
        if reported["TOTAL"][i] != core * 1024 or \
                reported["RESIDENT"][i] != sample["resident_words"] or \
                reported["PROCESS-WORDS"][i] != expected_words or \
                reported["PROC-SLOTS"][i] != len(sample["process_states"])+1:
            raise ValueError("native MEMINFO disagrees with actual MM "
                             "process APR/u-area ownership at checkpoint %d" % i)
    if len(samples[0]["process_states"]) != 1 or \
            len(samples[1]["process_states"]) != count + 1 or \
            len(samples[2]["process_states"]) != 1 or \
            samples[0]["packed_apr_count"] or \
            samples[2]["packed_apr_count"] or \
            samples[1]["packed_apr_count"] != count or \
            samples[1]["process_apr_count"] != 1:
        raise ValueError("RAW PURE reclaim/normal WAIT state not observed")
    if core == 48:
        active = {p["slot"]: p for p in samples[1]["process_states"]}
        if any(active[slot]["vm_words"] !=
               (3072 if slot <= 6 else 2048)
               for slot in range(2, 11)):
            raise ValueError("real child BRK logical size not conserved")
        # proc_high_slot is the last occupied high-water slot + 1,
        # not the configured number of descriptors. A new RUN may
        # extend this range, so its inequality with installed slots
        # proves this trigger was not a simple full process table.
        if samples[1]["process_high_slot"] >= \
                samples[1]["process_capacity"]:
            raise ValueError("refused trigger RUN was actually out of slots")
        if not (samples[1]["largest_free_words"] < 2048 <=
                samples[1]["free_words"]):
            raise ValueError("refused trigger lacked physical fragmentation")
        if any(p["physical"]["words"] != p["vm_words"] - 128
               for p in samples[1]["process_states"]
               if p["slot"] > 1):
            raise ValueError("RAW suffix not exact 128-word PURE skip")
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
    print("PASS v1673 %dK: native RUN %d children, PACKED RAW owners %d, "
          "free MM %d->%d->%d, largest %d->%d->%d" %
          (core, count, samples[1]["packed_apr_count"],
           samples[0]["free_words"], samples[1]["free_words"],
           samples[2]["free_words"],
           samples[0]["largest_free_words"],
           samples[1]["largest_free_words"],
           samples[2]["largest_free_words"]))


if __name__ == "__main__":
    try:
        run(sys.argv)
    except (ValueError, OSError) as exc:
        raise SystemExit("FAIL v1673 physical RUN/WAIT memory: " + str(exc))
