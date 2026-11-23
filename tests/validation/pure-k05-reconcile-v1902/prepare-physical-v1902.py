#!/usr/bin/env python3
"""Source-link original 48K FULL -5 and release only test-only MM pin."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def prepare(kit, build, probe, work, dxrcheck, objdump):
    baseline = runpy.run_path(str(kit / "tests/validation/"
                  "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    source = runpy.run_path(str(kit / "tests/validation/"
                  "pure-k05-source-free-reply-physical-v1893/prepare-v1893.py"))
    core = baseline["symbols"](build / "kcore.map")
    pure = baseline["symbols"](build / "pure-mres-v1612.map")
    if "proc_pure_recover_arm_v1902" not in core or \
            "proc_pure_mres_service_v1612" not in pure:
        raise ValueError("v1902 recovery code missing from source-built images")
    init = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    if init.count("#define P14_CHILDREN         5U") != 1 or \
            init.count("v1901_term_gate == 012345670123UL") != 1:
        raise ValueError("v1902 original five-child gated parent source missing")
    for unit in range(3):
        if (build / "media" / ("dtc%d.tap" % unit)).read_bytes() != \
                (build.parent / ("tsfs-v1638%d.dta" % unit)).read_bytes():
            raise ValueError("v1902 compressed original TSFS media drift")
    pure_base = baseline["read_probe"](build, probe)
    source_return = source["owner_free_return"](kit, build, pure_base,
                                                 dxrcheck, objdump)
    baseline["physical"](build, work, pure_base, dxrcheck)
    script = (work / "physical.ini").read_text(encoding="ascii")
    anchor = "echo V1845_END_FULL_PINNED\nnobreak\ndetach dtc3\n"
    if script.count(anchor) != 1:
        raise ValueError("original FULL_PINNED physical stage not unique")
    prefix, _ = script.split(anchor, 1)
    exp = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)$",
        (work / "expected-v1845.txt").read_text(encoding="ascii")))
    # The source MM descriptor is original MM extent #15, proved
    # independently by accepted v1895/v1901 physical traces.
    # All addresses here come from the NEW original linked KCORE map.
    source_meta = core["mm_extents"] + 0o37
    pin0 = (4 << 18) | 3
    pin1 = (1 << 21) | pin0
    table = 0
    # First source-linked full-system run discovers the newly relocated
    # process table from the actual guest, not from a stale old image.
    first = work.parent / "daimos-k05-reconcile-v1902-physical" / "physical.clean"
    if first.exists():
        older = first.read_text(encoding="ascii")
        if older.count("V1902_STAGE_FAILED_FULL\n") == 1 and \
                older.count("V1902_END_FAILED_FULL\n") == 1:
            block = older.split("V1902_STAGE_FAILED_FULL\n",1)[1].split(
                "V1902_END_FAILED_FULL\n",1)[0]
            values = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" %
                                core["proc_table"],block)
            if values and len(set(values)) == 1:
                table = int(values[0],8)
    if table and not 0o40000 < table < 0o140000:
        raise ValueError("original physical process table outside 48K")
    def snap(label):
        original = baseline["snapshot"](core, label)
        end = "echo V1845_END_%s\n" % label
        if not original.endswith(end):
            raise ValueError("original source-linked snapshot schema changed")
        extra = "examine %06o\n" % core["proc_table"]
        if table:
            extra += "examine %06o-%06o\n" % (table,table+0o20)
        return (original[:-len(end)].replace("V1845_", "V1902_") +
                extra + "echo V1902_END_%s\n" % label)
    # Native MM_FREE(PACKED) is forced to reject only by one external
    # test-only MM pin. Never fake AC1, native free, owner, or process.
    script = (prefix + "echo V1845_END_FULL_PINNED\n" +
        "nobreak\nbreak %06o\ncont\n" % (source_return - 1) +
        "echo V1902_NATIVE_SOURCE_FREE_CALL\n" +
        "examine %06o\n" % source_meta +
        "deposit %06o %012o\n" % (source_meta, pin1) +
        "echo V1902_TEST_ONLY_PIN\nexamine %06o\n" % source_meta +
        "echo V1902_END_TEST_ONLY_PIN\n" +
        "break %06o\ncont\n" % source_return +
        "echo V1902_REAL_MM_FREE_REFUSED\nexamine 1\n" +
        snap("NATIVE_REFUSED") +
        "nobreak\nbreak %06o\ncont\n" % exp["service_return"] +
        "echo V1902_ORIGINAL_FAILED_FULL_RETURN\nexamine 1\n" +
        snap("FAILED_FULL") +
        "nobreak\nexpect \"HB\"\ncont\n" +
        "echo V1902_REAL_PARENT_HEARTBEAT_PINNED\n" +
        snap("PINNED_HB") +
        "echo V1902_EXTERNAL_PIN_RELEASE\n" +
        "examine %06o\n" % source_meta +
        "deposit %06o %012o\n" % (source_meta, pin0) +
        "echo V1902_END_PIN_RELEASE\n" +
        "nobreak\nexpect \"HB\"\ncont\n" +
        "echo V1902_REAL_PARENT_HEARTBEAT_AFTER_PIN\n" +
        snap("POST_PIN_HB") +
        "nobreak\nexpect \"HB\"\ncont\n" +
        "echo V1902_REAL_PARENT_HEARTBEAT_RETRY\n" +
        snap("RETRY_HB") +
        "exit\n")
    if script.count("deposit %06o %012o" % (source_meta, pin1)) != 1 or \
            script.count("deposit %06o %012o" % (source_meta, pin0)) != 1 or \
            "detach dtc3\n" in script:
        raise ValueError("v1902 source pin/release controller drift")
    (work / "physical.ini").write_text(script, encoding="ascii")
    (work / "expected-v1902.txt").write_text(
        "source_meta %06o\nsource_pin0 %012o\nsource_pin1 %012o\n"
        "source_call %06o\nsource_return %06o\nservice_return %06o\n"
        "pure_base %06o\nprocess_table %06o\n" %
        (source_meta,pin0,pin1,source_return-1,source_return,
         exp["service_return"],pure_base,table),encoding="ascii")
    print("v1902: original 48K source free %06o/%06o, PURE %06o, source MM %06o" %
          (source_return-1,source_return,pure_base,source_meta))


if __name__ == "__main__":
    if len(sys.argv) != 7:
        raise SystemExit("usage: prepare-physical-v1902.py kit build probe work dxrcheck objdump")
    try:
        prepare(*(Path(a) for a in sys.argv[1:]))
    except (OSError, ValueError, AssertionError, KeyError) as e:
        raise SystemExit("FAIL v1902 original physical controller: " + str(e))
