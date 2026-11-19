#!/usr/bin/env python3
"""Fail-closed negative cases against the actual v1678 MM A/B/C trace.

No injected/forged event is counted as positive physical proof. Each
mutation alters one existing original physical word or native MEMINFO
value and must be refused by the same original-MM-backed v1678 oracle.
"""
import re
import subprocess
import sys
from pathlib import Path


def symbol(path, name):
    found = re.findall(r"^" + re.escape(name) + r"\s+([0-7]+)\s*$",
                       Path(path).read_text(encoding="ascii"), re.M)
    if len(found) != 1:
        raise ValueError("missing source-linked MM symbol " + name)
    return int(found[0], 8)


def section(text, token):
    a = text.index("V1673 HOLD " + token)
    b = text.index("V1673 RELEASE " + token, a)
    return (a, b, text[a:b])


def words(text, token):
    raw = section(text, token)[2]
    pairs = re.findall(r"(?m)^(?:sim> )?([0-7]{3,7}):\s+([0-7]{12})\s*$",
                       raw)
    vals = {}
    for address, value in pairs:
        i = int(address, 8)
        if i in vals:
            raise ValueError("duplicate original physical MM word")
        vals[i] = int(value, 8)
    return vals


def corrupt_word(text, token, address, bit):
    a, b, raw = section(text, token)
    pat = r"(?m)^((?:sim> )?%o:\s+)([0-7]{12})(\s*)$" % address
    found = list(re.finditer(pat, raw))
    if len(found) != 1:
        raise ValueError("no unique original word %o at %s" %
                         (address, token))
    hit = found[0]
    patched = (raw[:hit.start(2)] +
               "%012o" % (int(hit.group(2), 8) ^ bit) +
               raw[hit.end(2):])
    return text[:a] + patched + text[b:]


def run(args):
    if len(args) != 7:
        raise ValueError("usage: run-negative-v1678.py console.clean "
                         "fixture.map kcore.map accepted.json workdir variant")
    console, fixture, coremap, accepted, target, variant = args[1:]
    root = Path(__file__).resolve().parent
    work = Path(target)
    work.mkdir(parents=True, exist_ok=True)
    original = Path(console).read_text(encoding="ascii")
    cmd = [sys.executable, str(root / "measure-v1678.py"), fixture,
           coremap]
    check = subprocess.run(cmd + [console, "48", str(work / "positive.json")],
                           text=True, capture_output=True)
    if check.returncode != 0:
        raise ValueError("the original positive MM trace fails:\n" +
                         check.stdout + check.stderr)
    if (work / "positive.json").read_bytes() != Path(accepted).read_bytes():
        raise ValueError("original positive MM report differs from accepted")
    b = words(original, "B")
    c = words(original, "C")
    mm_extents = symbol(coremap, "mm_extents")
    mm_count = b[symbol(coremap, "mm_extent_count")]
    packed_index = next((i for i in range(mm_count)
                         if (b[mm_extents + 2 * i + 1] >> 18) & 7 == 4), None)
    if packed_index is None:
        raise ValueError("original physical MM has no packed process")
    packed_span = mm_extents + 2 * packed_index
    packed_meta = packed_span + 1
    # Derive actual failed/RESIDENT child directly from the original
    # source-signed report, not an arbitrary hard-coded process slot.
    import json
    report = json.loads(Path(accepted).read_text(encoding="ascii"))
    slot = report["rejected_resident_slot"]
    proc_table = b[symbol(coremap, "proc_table")]
    resident_meta = proc_table + 3 * slot
    mutated = [
        ("resident-transition", corrupt_word(original, "B",
                                               resident_meta, 1 << 16)),
        ("packed-span", corrupt_word(original, "B", packed_span,
                                     1 << 18)),
        ("packed-pin", corrupt_word(original, "B", packed_meta,
                                    1 << 21)),
        ("unrecovered-C", corrupt_word(original, "C", mm_extents,
                                      1 << 18)),
    ]
    pat = r"(?m)^V1673 PROCESS-WORDS ([0-9]+)\s*$"
    hits = list(re.finditer(pat, original))
    if len(hits) != 3:
        raise ValueError("original native MEMINFO has no unique B entry")
    hit = hits[1]
    mutated.append(("native-meminfo", original[:hit.start(1)] +
                    str(int(hit.group(1)) + 1) + original[hit.end(1):]))
    for name, content in mutated:
        path = work / (variant + "-unsafe-" + name + ".clean")
        path.write_text(content, encoding="ascii")
        proc = subprocess.run(cmd + [str(path), "48",
                                     str(work / (name + ".json"))],
                              text=True, capture_output=True)
        if proc.returncode == 0 or \
                "FAIL v1678 physical precommit MM oracle:" not in \
                (proc.stderr + proc.stdout):
            raise ValueError("unsafe original physical " + name +
                             " not rejected by v1678 MM oracle: " +
                             proc.stdout + proc.stderr)
        print("PASS v1678: original physical " + name + " mutant rejected")
    print("PASS v1678: five original MM/PROC/MEMINFO tamper cases rejected")


if __name__ == "__main__":
    try:
        run(sys.argv)
    except (ValueError, OSError) as exc:
        raise SystemExit("FAIL v1678 original MM negative suite: " + str(exc))
