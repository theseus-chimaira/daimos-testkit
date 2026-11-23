#!/usr/bin/env python3
"""Verify original physical PDP-6 MM owners through DTC3 FULL loss/return."""

from pathlib import Path
import re
import runpy
import sys


def run(kit, build, work):
    stage_module = runpy.run_path(str(
        kit / "tests/diagnostics/pure-full-restore-v1638/audit-v1638.py"))
    symbols = stage_module["symbols"]
    stage = stage_module["stage"]
    dxr_words = stage_module["dxr_words"]
    core = symbols((build / "kcore.map").read_text(encoding="ascii"))
    pure = symbols((build / "pure-mres-v1612.map").read_text(
        encoding="ascii"))
    transcript = (work / "physical.clean").read_text(encoding="ascii")
    expected = (work / "expected-v1845.txt").read_text(encoding="ascii")
    expected = dict((key, int(value, 8)) for key, value in
                    re.findall(r"(?m)^([a-z_]+)\s+([0-7]+)\s*$", expected))
    source = (build / "../user/init-v1614.c").resolve().read_text(
        encoding="ascii")
    root = (build / "../tsfs-root-v1638.manifest").resolve().read_text(
        encoding="ascii")
    plain = dxr_words((build / "../user/init.dxr").resolve().read_bytes())
    compressed = dxr_words((build / "../user/comp-v1638.dxr").resolve().read_bytes())

    for snippet in ("#define P14_CHILDREN         5U",
                    "pid[i] = p14_spawn(rd, i != 0U);",
                    "denied = p14_spawn(rd, 1U);",
                    "p14_seed_secondary_v1643(void)",
                    "dsys_unmount(p14_mount_v1643)",
                    "SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE",
                    "dsys_wait((unsigned int)pid[i], &status, 0U)",
                    "(void)p14_char('Z');"):
        assert snippet in source, "source guest contract drifted: " + snippet
    assert "F /SYSTEM/COMP " in root
    assert plain[0] == compressed[0] and plain[2] == compressed[2]
    assert (compressed[1] & 0o300000) == 0o300000
    assert (plain[1] & 0o300000) == 0o200000
    skip = ((compressed[2] >> 18) + 0o20) & ~0o177
    raw_words = 0o10000 - skip
    assert raw_words > 0 and 0 < skip < 0o10000

    assert "MEM                                  48 K" in transcript
    assert "PURE                              LOADED" in transcript
    assert "DTFS                              LOADED" in transcript
    assert "aaaaax[B" in transcript
    # The first, TSFS-root child completes before the secondary-backed
    # FULL entry. The other four resume only after the same reel returns.
    assert "}Lw\nBreakpoint, PC:" in transcript
    assert "wwwwZV1845_STAGE_Z" in transcript
    assert "HALT instruction, PC: 000000" in transcript
    assert "HALT instruction, PC: 004074" not in transcript

    for marker in ("BOUNDED_FULL_SECONDARY", "DTC3_DETACHED",
                   "END_DTC3_DETACHED", "FAILED_FULL_RETURN",
                   "SAME_DTC3_REATTACHED", "END_DTC3_REATTACHED"):
        assert transcript.count("V1845_%s\n" % marker) == 1, marker
    assert "DTC3    147KW, not attached" in transcript
    assert transcript.index("V1845_END_FULL_PINNED\n") < transcript.index(
        "V1845_DTC3_DETACHED\n")
    assert transcript.index("V1845_END_ROLLED_BACK\n") < transcript.index(
        "V1845_SAME_DTC3_REATTACHED\n")

    def capture(name):
        block, extents = stage(transcript.replace("V1845_", "V1638_"),
                               core, name)
        owner = block[core["proc_current_slot"]]
        assert owner == (0 if name in ("FULL_PINNED", "ROLLED_BACK") else 1)
        root_word = block[core["vfs_namespace_root"]]
        assert root_word >> 24 == (7 << 6) | 1, "selected TSFS root changed"
        assert any(a == 0o130000 and b == 0o140000 and k == 1 and
                   pin == 0 and slot == 1
                   for a, b, k, pin, slot in extents)
        children = [(a, b, k, pin, slot) for a, b, k, pin, slot in extents
                    if slot in range(2, 7) and k in (1, 4)]
        return block, children

    for name in ("B", "A"):
        _, owners = capture(name)
        assert len(owners) == 5, "unexpected child descriptor count"
        assert {slot for _, _, _, _, slot in owners} == set(range(2, 7))
        assert all(k == 4 and b - a == raw_words and pin == 0
                   for a, b, k, pin, _ in owners)

    _, owners = capture("FULL_PINNED")
    targets = [(a, b, slot) for a, b, k, pin, slot in owners
               if k == 1 and pin == 1 and b - a == 0o10000]
    assert len(targets) == 1
    target, end, slot = targets[0]
    assert slot in range(3, 7), "FULL must target a secondary-backed child"
    sources = [(a, b, pin) for a, b, k, pin, owner in owners
               if k == 4 and owner == slot]
    assert len(sources) == 1 and sources[0][2] == 1
    start, limit, _ = sources[0]
    assert limit - start == raw_words
    assert end <= start or limit <= target, "source and target overlap"

    loader = expected["loader"]
    opcode = expected["loader_opcode"]
    assert re.search(r"Breakpoint, PC: %06o " % loader, transcript)
    assert ("%o:\t%012o" % (loader, opcode)) in transcript
    failed_pc = expected["service_return"]
    assert re.search(r"Breakpoint, PC: %06o " % failed_pc, transcript)
    failure = transcript.split("V1845_FAILED_FULL_RETURN\n", 1)[1].split(
        "V1845_STAGE_ROLLED_BACK\n", 1)[0]
    assert re.search(r"(?m)^1:\s*777777777774\s*$", failure), \
        "actual FULL loader did not return MM_ERR_INVAL (-4)"
    _, owners = capture("ROLLED_BACK")
    assert not any(k == 1 and owner == slot for _, _, k, _, owner in owners), \
        "incomplete destination remains a PROCESS MM owner"
    assert [(a, b, pin) for a, b, k, pin, owner in owners
            if k == 4 and owner == slot] == [(start, limit, 0)]
    assert all(pin == 0 for _, _, _, pin, _ in owners)
    _, owners = capture("Z")
    assert not owners, "child MM owner leaked after five EXIT/WAIT pairs"
    print("PASS v1845: physical 48K original FULL DTC3 loss/return, five owners")
    print("v1845: secondary slot%o source %06o..%06o, target %06o..%06o" %
          (slot, start, limit, target, end))


def main(argv):
    if len(argv) != 4:
        raise SystemExit("usage: verify-v1845.py testkit build evidence")
    try:
        run(*(Path(arg) for arg in argv[1:]))
    except (AssertionError, ValueError, KeyError, OSError, UnicodeError) as exc:
        raise SystemExit("FAIL v1845 physical K05 FULL source loss: " +
                         str(exc))


if __name__ == "__main__":
    main(sys.argv)
