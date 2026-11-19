#!/usr/bin/env python3
"""Source-linked PI6 clock and original MM owner lifetime after one wake.

This tests real guest scheduler progress and five independently blocked
PIPE readers while one genuine process executes or restores. No KCORE,
MM, PI6 or VFS instruction is injected in the simulator.
"""

import argparse
from pathlib import Path
import re
import runpy


STAGES = ("B", "A", "MOUNT_BUSY", "VNODE_BUSY", "PROTECTED",
          "WAKE_SENT", "WAKE_GUARD", "PI6_WINDOW", "PI6_GUARD",
          "RELEASED", "Z")


def audit(kmap, plain_dxr, compressed_dxr, trace, guest):
    here = Path(__file__).resolve().parent
    prior = runpy.run_path(str(here.parent /
                                "pure-backing-guards-v1644/audit-v1644.py"))
    basic = runpy.run_path(str(here.parent /
                                "pure-full-restore-v1638/audit-v1638.py"))
    # All v1644 guards, six original PACKED owners, source identity,
    # writable secondary media and six exact WAIT/EXIT assumptions still
    # hold. Reuse that strict accepted oracle, not a shortened version.
    prior["audit"](kmap, plain_dxr, compressed_dxr,
                   trace.replace("V1645_", "V1644_"), guest)

    for fragment in ("#define P14_WAKE_V1645      052345670123UL",
                     "dsys_write_words(wr, &wake, 1U) != 1",
                     "nread != 1 || word != P14_WAKE_V1645",
                     "dsys_sleep(0200U) != 0",
                     "(void)p14_char('H');", "(void)p14_char('T');"):
        assert fragment in guest, "missing original C89 PI6 protocol: " + fragment
    assert guest.count("p14_check_busy_v1644();") == 3
    assert guest.count("dsys_write_words(wr, &wake, 1U)") == 1
    assert "#define P14_CHILDREN         6U" in guest
    assert "dsys_close(wr) != 0" in guest

    syms = basic["symbols"](kmap)
    stage = basic["stage"]
    for name in ("proc_timer_clock", "clk_tick_count",
                 "proc_sched_deferred_ticks", "proc_current_slot",
                 "mm_extents", "vfs_mount_policy", "vfs_namespace_root"):
        assert name in syms

    snapshots = {}
    for label in STAGES:
        first, last = ("V1645_STAGE_%s\n" % label,
                       "V1645_END_%s\n" % label)
        assert trace.count(first) == 1 and trace.count(last) == 1
        assert trace.index(first) < trace.index(last)
        words, extents = stage(trace.replace("V1645_", "V1638_"),
                               syms, label)
        assert words[syms["proc_current_slot"]] == 1
        assert (words[syms["vfs_mount_policy"]] & 0o2) == 0
        assert words[syms["vfs_namespace_root"]] >> 24 == (7 << 6) | 1
        for name in ("proc_timer_clock", "clk_tick_count"):
            assert syms[name] in words, "PI6 source-linked counter not sampled"
        snapshots[label] = (words, extents)

    # The original complete snapshots have no overlaps or invalid types,
    # independently of whether one restoring child currently holds a
    # separate full APR and a pinned RAW source.
    start, end = ("B", "A")
    expected = {owner: (a, b) for a, b, kind, pin, owner
                in snapshots[start][1] if kind == 4 and 2 <= owner <= 7}
    assert set(expected) == set(range(2, 8))
    assert all((a, b) == expected.get(owner) and pin == 0
               for a, b, kind, pin, owner in snapshots[end][1]
               if kind == 4 and 2 <= owner <= 7)
    raw_length = set(b - a for a, b in expected.values())
    assert len(raw_length) == 1
    raw = raw_length.pop()
    comp = basic["dxr_words"](compressed_dxr)
    skipped = ((comp[2] >> 18) + 0o20) & ~0o177
    assert raw == 0o10000 - skipped

    for label in ("WAKE_SENT", "WAKE_GUARD", "PI6_WINDOW", "PI6_GUARD"):
        _, extents = snapshots[label]
        retained = [(owner, a, b, pin) for a, b, kind, pin, owner
                    in extents if kind == 4 and 2 <= owner <= 7]
        assert 5 <= len(retained) <= 6, \
            "wakeup lost more than one of the six PIPE readers"
        if label in ("PI6_WINDOW", "PI6_GUARD"):
            assert len(retained) == 5, \
                "first child did not finish during real PI6 sleep"
        assert len(set(o for o, a, b, pin in retained)) == len(retained)
        assert all((a, b) == expected[owner] and pin in (0, 1)
                   for owner, a, b, pin in retained), \
            "restoration changed/damaged a surviving PACKED source"
        full = [(a, b, pin, owner) for a, b, kind, pin, owner
                in extents if kind == 1 and 2 <= owner <= 7]
        assert len(full) <= 1, "more than one FULL destination at a time"
        if full:
            assert full[0][1] - full[0][0] == 0o10000
            assert full[0][2] == 1
            assert any(pin == 1 and owner == full[0][3]
                       for owner, a, b, pin in retained)

    def ticks(label, field):
        return snapshots[label][0][syms[field]]

    # Real original CLK PI6 interrupt must advance BOTH counters between
    # the initial one-word wake and the later completed sleep frontier.
    # The 17-bit scheduler timer wraps, while CLK's 36-bit count does not
    # wrap during this short run. A fake software kick cannot raise CLK.
    before = ticks("WAKE_SENT", "proc_timer_clock") & 0o377777
    after = ticks("PI6_WINDOW", "proc_timer_clock") & 0o377777
    delta = (after - before) & 0o377777
    assert 1 <= delta <= 0o10000, "no real PI6 timer epoch elapsed"
    clock_before = ticks("WAKE_SENT", "clk_tick_count")
    clock_after = ticks("PI6_WINDOW", "clk_tick_count")
    assert 1 <= clock_after - clock_before <= 0o10000, \
        "no original 60Hz CLK PI6 ticks during guest scheduling window"
    for a, b in zip(STAGES, STAGES[1:]):
        assert snapshots[b][0][syms["clk_tick_count"]] >= \
            snapshots[a][0][syms["clk_tick_count"]], \
            "original CLK counter went backward"

    assert trace.index("V1645_END_PROTECTED\n") < trace.index(
        "V1645_STAGE_WAKE_SENT\n")
    assert trace.index("V1645_END_WAKE_GUARD\n") < trace.index(
        "V1645_STAGE_PI6_WINDOW\n")
    assert trace.index("V1645_END_PI6_GUARD\n") < trace.index(
        "V1645_STAGE_RELEASED\n")
    partial_console = trace.split("V1645_END_PROTECTED\n", 1)[1].split(
        "V1645_STAGE_PI6_WINDOW\n", 1)[0]
    # The PDP-6 simulator may flush a writable Type-551 image in the
    # middle of user output: its diagnostic "DTC3: writing buffer to
    # file: ..." contains a lowercase w, but is NOT a guest child.
    partial_console = re.sub(
        r"DTC[0-7]: writing buffer to file: [^\n]*", "", partial_console)
    assert partial_console.count("w") == 1, \
        "a single PIPE token must allow exactly one child to complete"
    assert "!" not in trace
    assert "HALT instruction, PC: 000000" in trace

    for label in ("RELEASED", "Z"):
        children = [(a, b, kind, pin, owner) for a, b, kind, pin, owner
                    in snapshots[label][1] if kind in (1, 4) and 2 <= owner <= 7]
        assert not children

    print("v1645: real source-built 48K six-PACKED guest, RAW %06o octal" % raw)
    print("v1645: one real shared PIPE wake, five surviving RAW backing owners")
    print("v1645: original PI6 clock +%d ticks, scheduler epoch +%d" %
          (clock_after - clock_before, delta))
    print("v1645: all RW backing guards preserved, six original WAITs")
    print("PASS v1645: original 48K staged wake/PI6 and final unmount/HALT")


def main():
    p = argparse.ArgumentParser()
    for name in ("kcore_map", "plain_dxr", "compressed_dxr", "trace",
                 "guest_source"):
        p.add_argument(name, type=Path)
    args = p.parse_args()
    try:
        audit(args.kcore_map.read_text(encoding="ascii"),
              args.plain_dxr.read_bytes(), args.compressed_dxr.read_bytes(),
              args.trace.read_text(encoding="ascii"),
              args.guest_source.read_text(encoding="ascii"))
    except (AssertionError, ValueError, KeyError, UnicodeError) as exc:
        p.exit(1, "FAIL v1645 PI6 backing lifetime: %s\n" % exc)


if __name__ == "__main__":
    main()
