#!/usr/bin/env python3
"""Reject forged PI6 saved PC or removal of an original pinned FULL owner."""

from pathlib import Path
import re
import subprocess
import sys


def splice(text, first, last, mutate):
    if text.count(first) != 1 or text.count(last) != 1:
        raise ValueError("physical PI6 evidence markers not unique")
    prefix, remainder = text.split(first, 1)
    body, suffix = remainder.split(last, 1)
    changed = mutate(body)
    if changed == body:
        raise ValueError("negative mutation did not alter physical trace")
    return prefix + first + changed + last + suffix


def mutate_saved_pc(section, addr):
    pattern = r"(?m)^(%o:\s*)([0-7]{12})(\s*)$" % addr
    result = re.sub(pattern, r"\g<1>000000000000\g<3>", section, count=1)
    if result == section:
        raise ValueError("original hardware PI6 save PC absent")
    return result


def mutate_outside_mres(section, addr):
    pattern = r"(?m)^(%o:\s*)([0-7]{12})(\s*)$" % addr
    found = re.findall(pattern, section)
    if len(found) != 1:
        raise ValueError("missing unique original PI6 continuation")
    original = int(found[0][1], 8)
    forged = (original & ~0o777777) | 0o177777
    altered = re.sub(pattern,
                     lambda m: m[1] + ("%012o" % forged) + m[3],
                     section, count=1)
    if altered == section:
        raise ValueError("unable to forge out-of-MRES interrupted PC")
    return altered


def mutate_target_pin(section, base, count):
    words = {int(a, 8): int(v, 8) for a, v in re.findall(
        r"(?m)^([0-7]+):\s*([0-7]{12})$", section)}
    for i in range(words[count]):
        meta_addr = base + i * 2 + 1
        meta = words[meta_addr]
        if (meta >> 18) & 7 == 1 and (meta & 0o777777) == 3:
            if (meta >> 21) & 255 != 1:
                raise ValueError("original target was not pinned once")
            old = "%o:\t%012o" % (meta_addr, meta)
            new = "%o:\t%012o" % (meta_addr, meta & ~(1 << 21))
            if section.count(old) != 1:
                raise ValueError("missing exact target descriptor")
            return section.replace(old, new, 1)
    raise ValueError("missing original physical PROCESS target")


def run(kit, build, work):
    trace = work / "physical.clean"
    original = trace.read_text(encoding="ascii")
    expected = {}
    for line in (work / "expected-pi6-v1848.txt").read_text(
            encoding="ascii").splitlines():
        label, value = line.split()
        expected[label] = int(value, 8)
    symbols = {}
    for line in (build / "kcore.map").read_text(encoding="ascii").splitlines():
        parts = line.split()
        if len(parts) == 2 and re.fullmatch(r"[0-7]+", parts[1]):
            symbols[parts[0]] = int(parts[1], 8)
    wrong_pc = splice(original, "V1848_ORIGINAL_PI6_CLOCK\n",
        "V1848_STAGE_PI6_MIDFULL\n",
        lambda s: mutate_saved_pc(s, expected["pi6_save"]))
    wrong_mres = splice(original, "V1848_ORIGINAL_PI6_CLOCK\n",
        "V1848_STAGE_PI6_MIDFULL\n",
        lambda s: mutate_outside_mres(s, expected["pi6_save"]))
    wrong_pin = splice(original, "V1848_STAGE_PI6_MIDFULL\n",
        "V1848_END_PI6_MIDFULL\n",
        lambda s: mutate_target_pin(s, symbols["mm_extents"],
                                    symbols["mm_extent_count"]))
    for name, text, diagnostic in (
        ("saved-hardware-PC", wrong_pc, "PI6 saved interrupt PC missing"),
        ("out-of-MRES-continuation", wrong_mres,
         "PI6 saved PC outside original source-linked PURE MRES"),
        ("mid-FULL-target-pin", wrong_pin, "PI6 entry changed pinned FULL")):
        trace.write_text(text, encoding="ascii")
        try:
            result = subprocess.run([sys.executable,
                str(kit / "tests/validation/pure-k05-midfull-pi6-v1848/"
                          "verify-v1848.py"), str(kit), str(build), str(work)],
                capture_output=True, text=True)
        finally:
            trace.write_text(original, encoding="ascii")
        if result.returncode == 0 or diagnostic not in result.stderr:
            raise ValueError("physical v1848 mutant not rejected: " + name +
                             " (" + result.stderr.strip() + ")")
        print("PASS v1848: original %s mutation rejected" % name)


def main(argv):
    if len(argv) != 4:
        raise SystemExit("usage: negative-v1848.py kit build evidence")
    try:
        run(*(Path(s) for s in argv[1:]))
    except (AssertionError, ValueError, KeyError, OSError, UnicodeError) as exc:
        raise SystemExit("FAIL v1848 negative physical PI6 oracle: " + str(exc))


if __name__ == "__main__":
    main(sys.argv)
