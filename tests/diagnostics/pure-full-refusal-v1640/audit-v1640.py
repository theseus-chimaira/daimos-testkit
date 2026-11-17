#!/usr/bin/env python3
"""Audit actual 48K FULL NOMEM/rollback before later successful restore.

Read-only original MM tables must demonstrate an owned pinned RAW
suffix before the failed allocation, and the SAME unpinned suffix
after the real production rollback. A later FULL call must have a
separately owned pinned process APR. No simulator deposit is used.
"""

import argparse
from pathlib import Path
import re
import runpy


def audit(kcore_map, mres_map, mres_dxrcheck, trace, guest,
          plain, compressed, manifest):
    helper = runpy.run_path(str(Path(__file__).resolve().parent.parent /
                                "pure-full-restore-v1638/audit-v1638.py"))
    symbols, stage, dxr_words = (helper[name] for name in
                                ("symbols", "stage", "dxr_words"))
    syms, mres = symbols(kcore_map), symbols(mres_map)
    base = 0o32026
    assert mres["proc_pure_ram_restore_v1391"] == 0o2207
    assert mres["mm_alloc_aligned_noreclaim"] == 0o1461
    assert mres["exec_image_full_bounded_v1391"] == 0o3224
    locations = {"alloc": base + 0o2310,
                 "rollback": base + 0o433,
                 "loader": base + 0o3224}
    for off, expected in ((0o2307, "260740001461"),
                          (0o0432, "260740002207"),
                          (0o3224, "200000000004")):
        assert ("IMAGE  %06o %s" % (off, expected)) in mres_dxrcheck
    for name, op in (("alloc", "MOVE"), ("rollback", "JUMPN"),
                     ("loader", "MOVE")):
        assert ("%o:\t" % locations[name]) in trace
        assert re.search(r"Breakpoint, PC: %06o " % locations[name],
                         trace), "missing actual %s source-PC" % name

    for marker in ("V1640_ALLOC_RETURN", "V1640_ROLLBACK_RETURN",
                   "V1640_BOUNDED_FULL"):
        assert trace.count(marker + "\n") == 1
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    assert "aaaaaax[BV1640_STAGE_B" in trace
    assert "LwwwwwwZV1640_STAGE_Z" in trace or \
           "ZV1640_STAGE_Z" in trace
    assert "HALT instruction" in trace
    for fragment in ("#define P14_CHILDREN         6U",
                     "pid[i] = p14_spawn(rd, i != 1U);",
                     "denied = p14_spawn(rd, 1U);",
                     "p14_compressed_path[3]",
                     "if (denied != -1)",
                     "dsys_read_words(0, &word, 1U)",
                     "p14_data[0] != 012345670123UL",
                     "p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL",
                     "dsys_wait((unsigned int)pid[i], &status, 0U)",
                     "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                     "(void)p14_char('Z');"):
        assert fragment in guest, "unmatched guest source: " + fragment
    p, c = dxr_words(plain), dxr_words(compressed)
    assert p[0] == c[0] and p[2] == c[2]
    assert p[1] >> 18 == c[1] >> 18
    assert (p[1] & 0o300000) == 0o200000
    assert (c[1] & 0o300000) == 0o300000
    assert "F /SYSTEM/COMP " in manifest

    data = {}
    for label in ("B", "A", "PINNED_FAILURE", "ROLLED_BACK",
                  "FULL", "Z"):
        words, ext = stage(trace.replace("V1640_", "V1638_"),
                           syms, label)
        # The reusable parser uses the v1638 literal stage markers.
        expected_slot = 0 if label in ("PINNED_FAILURE", "ROLLED_BACK",
                                       "FULL") else 1
        assert words[syms["proc_current_slot"]] == expected_slot
        assert any(a == 0o130000 and b == 0o140000 and kind == 1
                   and owner == 1 and pin == 0
                   for a, b, kind, pin, owner in ext)
        children = [(a, b, kind, pin, owner) for a, b, kind, pin, owner
                    in ext if kind in (1, 4) and 2 <= owner <= 7]
        if label in ("B", "A", "PINNED_FAILURE", "ROLLED_BACK"):
            assert len(children) == 6
            assert {o for _, _, _, _, o in children} == set(range(2, 8))
            assert all(k == 4 and b-a == 0o7000 for a, b, k, p, o
                       in children)
        elif label == "Z":
            assert not children, "zombie PROCESS or PACKED owner"
        data[label] = (words, ext, children)

    for label in ("B", "A", "PINNED_FAILURE", "ROLLED_BACK"):
        _, _, children = data[label]
        owners = [(a, b, kind, owner) for a, b, kind, pin, owner in children]
        base_owners = [(a, b, kind, owner) for a, b, kind, pin, owner
                       in data["B"][2]]
        assert owners == base_owners, "refusal mutated original raw suffix"
    for label in ("B", "A", "ROLLED_BACK"):
        assert all(pin == 0 for _, _, kind, pin, owner in data[label][2]), \
            "source retained a leaked MM pin after refused restore"
    assert [(owner, pin) for a, b, kind, pin, owner in
            data["PINNED_FAILURE"][2] if pin] == [(2, 1)]

    def read_ac(marker):
        block = trace.split(marker + "\n", 1)[1].split(
            "V1640_STAGE_", 1)[0]
        data = {int(a, 8): int(b, 8) for a, b in re.findall(
            r"(?m)^\s*([1-4]):\s*([0-7]{1,12})\s*$", block)}
        assert set(data) == {1, 2, 3, 4}
        return data

    denied = read_ac("V1640_ALLOC_RETURN")
    rolled = read_ac("V1640_ROLLBACK_RETURN")
    assert denied[1] == 0o777777777777, \
        "the v1391 destination allocation was not genuinely NOMEM"
    assert rolled[1] == 0o777777777777, \
        "the original v1391 NOMEM result changed during source rollback"
    # The successful retry callback must have an already pinned full
    # process APR for a compressed child, distinct from its PACKED source.
    successful = read_ac("V1640_BOUNDED_FULL")
    dest = successful[2]
    assert successful[4] == 0o10000
    assert dest > 0 and dest % 0o2000 == 0
    _, _, children = data["FULL"]
    full = [(a, b, pin, owner) for a, b, k, pin, owner in children
            if k == 1 and a == dest and b-a == 0o10000 and pin == 1]
    assert len(full) == 1
    slot = full[0][3]
    assert slot in (2, 4, 5, 6, 7), \
        "FULL callback did not target an original compressed PURE child"
    packed = [(a, b, pin, owner) for a, b, k, pin, owner in children
              if k == 4 and owner == slot]
    assert len(packed) == 1 and packed[0][2] == 1
    assert packed[0][1] - packed[0][0] == 0o7000
    assert dest + 0o10000 <= packed[0][0] or \
           packed[0][1] <= dest, "restored APR aliases its raw source"
    print("v1640: initial FULL no-APR allocation returned -1 for compressed slot2")
    print("v1640: 6 original unmodified PACKED owners; slot2 pin 1 -> 0")
    print("v1640: later bounded FULL slot%o target=%06o preserves raw source" %
          (slot, dest))
    print("PASS v1640: actual FULL NOMEM rollback, retry, six user EXIT/WAIT")
    print("v1640: injected VFS failure and transient peak RAM remain OPEN")


def main():
    p = argparse.ArgumentParser()
    for name in ("kcore_map", "mres_map", "mres_dxrcheck", "trace",
                 "guest", "plain", "compressed", "manifest"):
        p.add_argument(name, type=Path)
    args = p.parse_args()
    paths = [getattr(args, name) for name in
             ("kcore_map", "mres_map", "mres_dxrcheck", "trace",
              "guest", "plain", "compressed", "manifest")]
    try:
        items = [(path.read_bytes() if i in (5, 6) else
                  path.read_text(encoding="ascii"))
                 for i, path in enumerate(paths)]
        audit(*items)
    except (AssertionError, ValueError, KeyError, UnicodeError) as exc:
        p.exit(1, "FAIL v1640 physical FULL refusal audit: %s\n" % exc)


if __name__ == "__main__":
    main()
