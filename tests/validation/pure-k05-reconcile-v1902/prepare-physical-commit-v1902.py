#!/usr/bin/env python3
"""Observe real PDP6 slot-0 PURE rollback native MM free and unlock."""

from pathlib import Path
import re
import runpy
import subprocess
import sys


def one(text, name):
    matches = re.findall(r"(?m)^%s\s+([0-7]+)\s*$" % name, text)
    if len(matches) != 1:
        raise ValueError("versioned original physical expectation missing: " + name)
    return int(matches[0], 8)


def image(dxrcheck, path):
    text = subprocess.check_output([str(dxrcheck), "-d", str(path)],
                                   encoding="ascii")
    nums = re.findall(r"(?m)^DXR magic=DXR entry=[0-7]+ image=([0-7]+)", text)
    if len(nums) != 1:
        raise ValueError("source-built DXR size missing")
    words = dict((int(a, 8), int(w, 8)) for a, w in re.findall(
        r"(?m)^IMAGE\s+([0-7]+)\s+([0-7]{12})\s*$", text))
    return int(nums[0], 8), words


def prepare(kit, build, probe, work, dxrcheck, objdump):
    prior = runpy.run_path(str(kit / "tests/validation/"
                  "pure-k05-reconcile-v1902/prepare-physical-v1902.py"))
    base = runpy.run_path(str(kit / "tests/validation/"
                  "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    prior["prepare"](kit, build, probe, work, dxrcheck, objdump)
    core = base["symbols"](build / "kcore.map")
    pure = base["symbols"](build / "pure-mres-v1612.map")
    old = (work / "expected-v1902.txt").read_text(encoding="ascii")
    physical_base = one(old, "pure_base")
    source_meta = one(old, "source_meta")
    if source_meta != core["mm_extents"] + 0o37:
        raise ValueError("original RAW descriptor is not exact source slot3")
    image_kcore, kcore_words = image(dxrcheck, build / "kcore.dxr")
    image_pure, pure_words = image(dxrcheck, build / "pure-mres-v1612.dxr")
    if image_kcore != 0o24165 or image_pure != 0o4615:
        raise ValueError("v1902 actual KCORE/PURE image words changed")
    # Anchored by v1900 actual runtime proc_table=045014. Both source-
    # built installed image sizes are authoritative; verify actual pointer
    # again at every physical checkpoint, not merely this prediction.
    table = 0o45014 + image_kcore - 0o24147 + image_pure - 0o4131
    uarea = 0o46133 + (table - 0o45014)
    if table != 0o45516 or uarea != 0o46635:
        raise ValueError("original runtime table/u-area relocation drifted")
    object_path = build / "proc_pure_service_v1612.dobj"
    relocs = subprocess.check_output([str(objdump), "-r", str(object_path)],
                                     encoding="ascii")
    frees = [int(x, 8) for x in re.findall(
        r"(?m)^\.text\+([0-7]{6}) type=2 symbol=mm_free addend=", relocs)]
    if frees != [0o610]:
        raise ValueError("compiled v1902 idle rollback must have ONE MM free")
    obj_symbols = subprocess.check_output([str(objdump), "-t", str(object_path)],
                                          encoding="ascii")
    origins = re.findall(r"(?m)^\s*\d+ DEF\s+\.text\s+[0-7]{6},,([0-7]{6})\s+proc_pure_mres_service_v1612\s*$", obj_symbols)
    if len(origins) != 1:
        raise ValueError("compiled v1902 PURE service label not unique")
    call = pure["proc_pure_mres_service_v1612"] + frees[0] - int(origins[0], 8)
    if pure_words.get(call) != (0o260740000000 | core["mm_free"]):
        raise ValueError("v1902 PURE recovery not the original MM PUSHJ")
    recovery = physical_base + call
    # Exact encoded instruction triple from folded KCORE. Folded labels
    # are not reliable instruction-start indicators; match real code.
    service_calls = [a for a, op in kcore_words.items()
                     if op == (0o260740000000 | core["proc_swap_service_one"])
                     and kcore_words.get(a-1) == 0o435040400000
                     and kcore_words.get(a-2) == 0o200040000010]
    if len(service_calls) != 1:
        raise ValueError("original tagged slot0 service call not unique")
    reaper_return = service_calls[0] + 1
    # The original PURE KCC recovery clears u-area FINALIZE then the
    # process TRANSITION bit at precisely these original machine words.
    # Code folding can redirect the later KCORE reaper return, so stop
    # HERE after both genuine stores rather than at an assumed JRST.
    if (pure_words.get(0o635), pure_words.get(0o637),
            pure_words.get(0o640)) != (0o402004000067,
                                      0o406337777774,
                                      0o200040000012):
        raise ValueError("original source-linked retry/TRANSITION stores changed")
    transition_cleared = physical_base + 0o640

    script = (work / "physical.ini").read_text(encoding="ascii")
    anchor = "echo V1902_END_PIN_RELEASE\n"
    if script.count(anchor) != 1:
        raise ValueError("old source physical pin release checkpoint not unique")
    head, _ = script.split(anchor, 1)
    # Preserve original v1902 MM checkpoints, but also snapshot the
    # dynamically relocated proc_table and the live executive u-area
    # BEFORE the external source pin is released. The stock controller
    # captures MM descriptors only; accepting a later synthetic parent
    # record would not prove the real saved CPU continuation survived.
    for label in ("FAILED_FULL", "PINNED_HB"):
        end = "echo V1902_END_%s\n" % label
        start = "echo V1902_STAGE_%s\n" % label
        if head.count(start) != 1 or head.count(end) != 1:
            raise ValueError("original physical pre-release stage drift: " + label)
        existing = head.split(start,1)[1].split(end,1)[0]
        required = ("examine %06o-%06o\n" % (table,table+0o20),
                    "examine %06o\n" % core["proc_timer_clock"],
                    "examine %06o\n" % (uarea+0o20),
                    "examine %06o\n" % (uarea+0o24),
                    "examine %06o\n" % (uarea+0o67))
        added = "".join(x for x in required if x not in existing)
        head = head.replace(end, added+end,1)

    def snap(stage):
        full = base["snapshot"](core, stage).replace("V1845_", "V1902REC_")
        end = "echo V1902REC_END_%s\n" % stage
        if not full.endswith(end):
            raise ValueError("original exact MM snapshot tail changed")
        return (full[:-len(end)] +
                "examine %06o\n" % core["proc_table"] +
                "examine %06o-%06o\n" % (table, table+0o20) +
                "examine %06o\n" % core["proc_timer_clock"] +
                "examine %06o\n" % (uarea+0o20) +
                "examine %06o\n" % (uarea+0o24) +
                "examine %06o\n" % (uarea+0o67) + end)

    tail = (anchor +
            "nobreak\nbreak %06o\ncont\n" % recovery +
            "echo V1902REC_ORIGINAL_NATIVE_PROCESS_FREE_CALL\n" +
            snap("BEFORE_TARGET_FREE") +
            "nobreak\nbreak %06o\ncont\n" % (recovery+1) +
            "echo V1902REC_ORIGINAL_NATIVE_PROCESS_FREE_RETURN\nexamine 1\n" +
            snap("TARGET_FREED") +
            "nobreak\nbreak %06o\ncont\n" % transition_cleared +
            "echo V1902REC_ORIGINAL_SLOT0_TRANSITION_CLEAR\n" +
            snap("TRANSITION_UNLOCKED") +
            "nobreak\nexpect \"HB\"\ncont\n" +
            "echo V1902REC_ORIGINAL_PARENT_USER_AFTER_RECOVERY\n" +
            snap("PARENT_AFTER_RECOVERY") + "exit\n")
    if script.count("deposit %06o" % source_meta) != 2 or \
            "deposit" in tail:
        raise ValueError("physical target rollback adds no test-only MM deposits")
    (work / "physical.ini").write_text(head+tail, encoding="ascii")
    with (work / "expected-v1902-commit.txt").open("w", encoding="ascii") as out:
        out.write(("target_call %06o\ntarget_return %06o\n"
                   "reaper_return %06o\ntransition_clear %06o\nprocess_table %06o\n"
                   "uarea %06o\n") %
                  (recovery,recovery+1,reaper_return,transition_cleared,
                   table,uarea))
    print("v1902 true original native MM free=%06o/return=%06o" %
          (recovery,recovery+1))
    print("v1902 original KCC cleared TRANSITION at %06o; runtime table %06o" %
          (transition_cleared,table))


if __name__ == "__main__":
    if len(sys.argv) != 7:
        raise SystemExit("usage: prepare-physical-commit-v1902.py kit build probe work dxrcheck objdump")
    try:
        prepare(*(Path(s) for s in sys.argv[1:]))
    except (ValueError, OSError, KeyError, AssertionError) as exc:
        raise SystemExit("FAIL v1902 real native MM rollback physical: " + str(exc))
