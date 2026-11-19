#!/usr/bin/env python3
"""Replay every watched PDP-6 physical MM descriptor write after PID1 starts.

The simulator traps actual physical writes, never user virtual PC addresses.
A write event contains the exact modified physical word after the store.
Replay against the original full CTY A snapshot and cross-check B and C.
Every count update is the final MM insert/delete commit. Only those count
commits and proven in-place shrink/grow span writes are high-water samples.
Intermediate table shifts and metadata writes are replayed but NEVER
misreported as new physical RAM allocations even if briefly consistent.
"""

import importlib.util
import hashlib
import json
import re
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent


def module(filename, name):
    path = HERE.parent / name / filename
    spec = importlib.util.spec_from_file_location(filename[:-3], path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


P1673 = module("measure-v1673.py", "pure-runtime-reclaim-v1673")
P1670 = module("trace-v1670.py", "pure-kinit-peak-v1670")
RE_WRITE = re.compile(
    r"^Breakpoint, PC:\s+([0-7]+)[^\n]*\n"
    r"(?:sim> )?([0-7]{3,7}):[ \t]+([0-7]{12})[ \t]*$", re.M)


def expect(condition, reason):
    if not condition:
        raise ValueError(reason)


def segment(source, begin, end):
    expect(source.count(begin) == 1 and source.count(end) == 1,
           "missing or repeated physical CTY marker " + begin)
    left = source.index(begin) + len(begin)
    right = source.index(end, left)
    expect(left < right, "out-of-order CTY markers")
    return source[left:right]


def replay(text, watched, shadow, addresses, index):
    matched = list(RE_WRITE.finditer(text))
    expect(text.count("Breakpoint, PC:") == len(matched),
           "unpaired or ambiguous SIMH MM write-break event")
    expect(matched, "no physical MM write events in runtime phase")
    valid = []
    commits = 0
    resizes = 0
    staging = 0
    # Only MM data arrays and count may mutate. Any arena/core change is
    # an unexpected runtime contract change, not an allowable new peak.
    mutable = set(range(addresses["mm_extents"],
                        addresses["mm_extents"] + 2 * 32))
    mutable.add(addresses["mm_extent_count"])
    for match in matched:
        pc, address, value = (int(v, 8) for v in match.groups())
        expect(address in watched, "unwatched physical MM address")
        expect(address in mutable, "runtime changed permanent MM geometry")
        shadow[address] = value
        is_commit = address == addresses["mm_extent_count"]
        is_span = (addresses["mm_extents"] <= address <
                   addresses["mm_extents"] + 2 * 32 and
                   (address - addresses["mm_extents"]) % 2 == 0)
        is_resize = is_span and (
            addresses["mm_process_shrink_pinned"] <= pc <
            addresses["mm_process_grow_pinned"] or
            addresses["mm_process_grow_pinned"] <= pc <
            addresses["mm_pin"])
        # mm_delete shifts before SOS count; mm_extent_insert shifts
        # before AOS count. Their partial descriptor views are NOT
        # allocations and can look valid by accident. Conversely the
        # shrink/grow paths change a span with one final HRLM store,
        # leaving count unchanged. Source-range qualification is safe:
        # this callback is for a *physical MM write* only.
        if not is_commit and not is_resize:
            staging += 1
            index += 1
            continue
        if is_commit:
            commits += 1
        else:
            resizes += 1
        entry = dict(event="mm-count" if is_commit else "mm-resize",
                     words=shadow)
        try:
            state = P1670.decode(entry, addresses, 48, index)
        except ValueError as exc:
            raise ValueError("invalid committed original-MM table: " +
                             str(exc)) from exc
        valid.append(dict(order=index, pc_octal="%06o" % pc,
                          address_octal="%06o" % address,
                          free=state["free"],
                          largest_free=state["largest_free"],
                          allocated=state["allocated"],
                          occupied_or_reserved=
                          state["occupied_or_reserved"],
                          committed=is_commit, resize=is_resize))
        index += 1
    expect(commits > 0, "no actual physical MM extent-count commits")
    expect(commits + resizes + staging == len(matched),
           "MM physical write sequence not fully classified")
    return dict(observed=len(matched), commits=commits,
                resizes=resizes, staging_writes=staging,
                stable=valid), index


def run(argv):
    if len(argv) != 6:
        raise ValueError("usage: trace-v1674.py fixture.map kcore.map "
                         "physical-console.clean v1673-report.json output.json")
    fixture, coremap, console, base_report, target = map(Path, argv[1:])
    content = console.read_text(encoding="ascii", errors="replace")
    physical = json.loads(base_report.read_text(encoding="ascii"))
    expect(physical["core_kwords"] == 48 and
           physical["children_requested"] == 9,
           "v1673 physical acceptance is not 48K nine-child RAW PURE")
    expect(content.count("V1673 PASS RUN EXIT WAIT") == 1,
           "incomplete native RUN/EXIT/WAIT guest")
    locations = ("mm_core_words", "mm_extent_capacity", "mm_extent_count",
                 "mm_arena_count", "sys_resident_words_immediate",
                 "mm_arenas", "mm_extents", "mm_process_shrink_pinned",
                 "mm_process_grow_pinned", "mm_pin")
    addresses = {name: P1673.lookup(coremap, name) for name in locations}
    watched = set(range(addresses["mm_extents"],
                        addresses["mm_extents"] + 2 * 32))
    watched.add(addresses["mm_extent_count"])
    watched.update(range(addresses["mm_arenas"], addresses["mm_arenas"] + 3))
    watched.update(addresses[name] for name in
                   ("mm_core_words", "mm_extent_capacity", "mm_arena_count"))
    expect(len(watched) == 71, "source-linked MM watcher address collision")
    watch_setup = segment(content, "V1673 HOLD A", "V1673 RELEASE A")
    armed = {int(value, 8) for value in re.findall(
        r"^(?:sim> )?SET BREAK -W ([0-7]+);", watch_setup, re.M)}
    expect(armed == watched, "not all MM physical write watches were armed")
    snapshots = P1673.observations(content, fixture)
    source = [event["words"] for event in snapshots]
    shadow = dict(source[0])
    for addr in watched:
        expect(addr in shadow, "missing initial original-MM physical word")
    first = segment(content, "V1673 RELEASE A", "V1673 HOLD B")
    second = segment(content, "V1673 RELEASE B", "V1673 HOLD C")
    phase_reports = []
    order = 0
    for phase, text, expected in zip(("A-to-B", "B-to-C"),
                                      (first, second), source[1:]):
        result, order = replay(text, watched, shadow, addresses, order)
        for addr in watched:
            expect(shadow[addr] == expected[addr],
                   "missed MM write or forged CTY checkpoint at %s: %o" %
                   (phase, addr))
        result["phase"] = phase
        phase_reports.append(result)
    disarm = segment(content, "V1673 HOLD C", "V1673 RELEASE C")
    expect("SET BREAK -W " not in disarm,
           "MM watches remain armed at guest completion")
    values = [e for phase in phase_reports for e in phase["stable"]]
    expect(values, "no validated physical MM mutation events")
    minimum = min(values, key=lambda v: v["free"])
    maximum = max(values, key=lambda v: v["occupied_or_reserved"])
    # The three accepted source-linked barrier states are required
    # independently. The event stream is NOT their replacement.
    baseline, pressure, reaped = (physical[name] for name in
                                   ("baseline", "pressure", "reaped"))
    expect(baseline["free_words"] == reaped["free_words"] == 27441 and
           pressure["free_words"] == 2794 and
           pressure["packed_apr_count"] == 9,
           "v1673 original physical RAW reclaim gate failed")
    # Final result bounds: we cannot see less free physical MM than
    # observed in a validated physical checkpoint.
    expect(minimum["free"] <= pressure["free_words"],
           "physical high-water missed accepted pressure checkpoint")
    report = dict(kernel_map_sha256=hashlib.sha256(coremap.read_bytes()).hexdigest(),
                  fixture_map_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest(),
                  core_kwords=48,
                  watches=len(watched), event_count=order,
                  committed_events=sum(p["commits"] for p in phase_reports),
                  resize_events=sum(p["resizes"] for p in phase_reports),
                  staging_writes=sum(p["staging_writes"]
                                     for p in phase_reports),
                  min_event_free=minimum["free"],
                  max_event_nonfree=maximum["occupied_or_reserved"],
                  peak_event=maximum, phases=phase_reports,
                  baseline_free=baseline["free_words"],
                  pressure_free=pressure["free_words"],
                  reaped_free=reaped["free_words"])
    target.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                      encoding="ascii")
    print("PASS v1674: %d original physical MM writes, %d count commits, "
          "min observed free %d, max nonfree %d" %
          (order, report["committed_events"], minimum["free"],
           maximum["occupied_or_reserved"]), flush=True)
    print("NOTE: committed MM insert/delete and in-place resize peak; "
          "not a process-instruction trace", flush=True)


if __name__ == "__main__":
    try:
        run(sys.argv)
    except (ValueError, OSError, KeyError, IndexError, TypeError) as exc:
        raise SystemExit("FAIL v1674 physical high-water replay: " + str(exc))
