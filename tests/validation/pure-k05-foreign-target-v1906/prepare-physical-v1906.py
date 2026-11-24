#!/usr/bin/env python3
"""Original 48K PDP-6: foreign-claimed FULL target, fail closed, then repair."""

from pathlib import Path
import hashlib
import re
import runpy
import subprocess
import sys


def one(path, key):
    found = re.findall(r"(?m)^%s\s+([0-7]+)$" % key,
                       path.read_text(encoding="ascii"))
    if len(found) != 1:
        raise ValueError("missing source-linked original symbol: " + key)
    return int(found[0],8)


def prepare(kit, build, probe, work, prefix):
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
            "a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be":
        raise ValueError("v1906 fixed KCORE differs from accepted v1903")
    if hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351":
        raise ValueError("v1906 PURE MRES not the source-built target escrow fix")
    old = runpy.run_path(str(kit / "tests/validation/"
                      "pure-k05-reconcile-v1902/prepare-physical-v1902.py"))
    old["prepare"](kit, build, probe, work,
                   prefix / "bin/dxrcheck",
                   prefix / "bin/pdp10-dec-none-objdump")
    base = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    decode = runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-reconcile-v1902/prepare-physical-commit-v1902.py"))
    core = base["symbols"](build / "kcore.map")
    pure = base["symbols"](build / "pure-mres-v1612.map")
    source_meta = one(work / "expected-v1902.txt", "source_meta")
    target_meta = source_meta + 2
    pure_base = one(work / "expected-v1902.txt", "pure_base")
    source_return = one(work / "expected-v1902.txt", "source_return")
    service_return = one(work / "expected-v1902.txt", "service_return")
    image_core,_ = decode["image"](prefix / "bin/dxrcheck",build / "kcore.dxr")
    image_pure,words = decode["image"](
        prefix / "bin/dxrcheck",build / "pure-mres-v1612.dxr")
    if image_core != 0o24167 or image_pure != 0o4761 or \
            source_meta != core["mm_extents"]+0o37 or \
            target_meta != core["mm_extents"]+0o41:
        raise ValueError("original 48K MM/image layout changed")
    # The original source-built transient KINIT places MM and process
    # slabs after the optional PURE image. Since fixed KCORE is byte-
    # identical, the sole image-length delta is 004761-004615=000144.
    # Read and verify both addresses against live process pointers.
    table = 0o45534 + image_pure-0o4615
    uarea = 0o46653 + image_pure-0o4615
    parent_gate = 0o130000 + base["symbols"](build.parent/"user/init.map")[
        "v1901_term_gate"]

    obj = build / "proc_pure_service_v1612.dobj"
    objdump = prefix / "bin/pdp10-dec-none-objdump"
    relocs = subprocess.check_output([str(objdump),"-r",str(obj)],
                                     encoding="ascii")
    frees = [int(x,8) for x in re.findall(
        r"(?m)^\.text\+([0-7]{6}) type=2 symbol=mm_free addend=",relocs)]
    symbols = subprocess.check_output([str(objdump),"-t",str(obj)],
                                      encoding="ascii")
    function = re.findall(
        r"(?m)^\s*\d+ DEF\s+\.text\s+[0-7]{6},,([0-7]{6})\s+"
        r"proc_pure_mres_service_v1612\s*$",symbols)
    if len(frees)!=1 or len(function)!=1:
        raise ValueError("original native mm_free relocation not unique")
    target_call = pure["proc_pure_mres_service_v1612"] + \
        frees[0] - int(function[0],8)
    if words.get(target_call) != (0o260740000000 | core["mm_free"]):
        raise ValueError("native PROCESS target mm_free PUSHJ mismatch")

    # Find the C compiler's original u[067]=0, bit-clear and store
    # sequence inside the linked PURE. Do NOT copy v1903 code offsets.
    matches = [a for a,op in words.items()
               if op==0o402004000067 and
               words.get(a+1)==0o201217777774 and
               words.get(a+2)==0o561300577777 and
               words.get(a+3)==0o406324000000]
    if len(matches)!=1:
        raise ValueError("original v1906 compiled transition-clear stores drifted")
    clear_pc = pure_base + matches[0]+4
    target_call += pure_base

    def snap(label):
        s = base["snapshot"](core,label).replace("V1845_","V1906_")
        end = "echo V1906_END_%s\n" % label
        if not s.endswith(end):
            raise ValueError("original physical MM snapshot schema drift")
        return (s[:-len(end)] +
                "examine %06o\n" % core["proc_table"] +
                "examine %06o-%06o\n" % (table,table+0o20) +
                "examine %06o\n" % core["proc_timer_clock"] +
                "examine %06o\n" % (core["proc_timer_clock"]+2) +
                "examine %06o\n" % (uarea+0o20) +
                "examine %06o\n" % (uarea+0o24) +
                "examine %06o\n" % (uarea+0o67) +
                "examine %06o\n" % parent_gate + end)

    script = (work/"physical.ini").read_text(encoding="ascii")
    anchor = "echo V1902_END_PIN_RELEASE\n"
    if script.count(anchor) != 1:
        raise ValueError("original source refusal and release stage drift")
    # A single explicitly unsafe physical MM-owner fault is injected.
    # It does not change the original source, target span, pin state,
    # child u-area, FINALIZE or kernel return values. The kernel must
    # keep TRANSITION and its exact target-base escrow in u[067].
    script = script.split(anchor,1)[0] + anchor
    script += ("echo V1906_FOREIGN_TARGET_INJECT\n" +
               "examine %06o\n" % target_meta +
               "deposit %06o %012o\n" % (target_meta,0o1000002) +
               "echo V1906_END_FOREIGN_TARGET_INJECT\n")
    for i in (1,2,3):
        script += ("nobreak all\nexpect \"HB\"\ncont\n" +
                   "echo V1906_FOREIGN_HELD_HB_%d\n" % i +
                   snap("FOREIGN_HELD_HB_%d" % i))
    # This is OPERATOR REPAIR OF CORRUPT TEST MM METADATA, not native
    # free or automatic ownership transfer. Only once repaired may
    # the original code resume its lawful target deletion.
    script += ("echo V1906_FOREIGN_TARGET_REPAIR\n" +
               "examine %06o\n" % target_meta +
               "deposit %06o %012o\n" % (target_meta,0o1000003) +
               "echo V1906_END_FOREIGN_TARGET_REPAIR\n" +
               "nobreak all\nbreak %06o\ncont\n" % target_call +
               "echo V1906_ORIGINAL_NATIVE_TARGET_FREE_CALL\n" +
               snap("BEFORE_TARGET_FREE") +
               "nobreak all\nbreak %06o\ncont\n" % (target_call+1) +
               "echo V1906_ORIGINAL_NATIVE_TARGET_FREE_RETURN\nexamine 1\n" +
               snap("TARGET_FREED") +
               "nobreak all\nbreak %06o\ncont\n" % clear_pc +
               "echo V1906_ORIGINAL_TRANSITION_CLEAR\n" +
               snap("UNLOCKED") +
               "nobreak all\nexpect \"HB\"\ncont\n" +
               "echo V1906_ORIGINAL_PARENT_AFTER_RECOVERY\n" +
               snap("PARENT_HB") +
               "nobreak all\nbreak %06o\ncont\n" % source_return +
               "echo V1906_SECOND_NATIVE_SOURCE_FREE_RETURN\nexamine 1\n" +
               snap("SOURCE_FREED") +
               "nobreak all\nbreak %06o\ncont\n" % service_return +
               "echo V1906_SECOND_FULL_SERVICE_RETURN\nexamine 1\n" +
               snap("FULL_COMMITTED") +
               "echo V1906_TEST_ONLY_PARENT_USER_GATE\n" +
               "examine %06o\n" % parent_gate +
               "deposit %06o %012o\n" % (parent_gate,0o12345670123) +
               "echo V1906_END_PARENT_USER_GATE\n" +
               "nobreak all\nexpect \"Z\"\ncont\n" +
               "echo V1906_ORIGINAL_PARENT_TYPED_WAIT_Z\n" +
               snap("PARENT_Z") +
               "cont\n" +
               "echo V1906_ORIGINAL_NATIVE_HALT\n" +
               snap("HALT") + "exit\n")
    script = script.replace("nobreak\n","nobreak all\n")
    if script.count("deposit %06o %012o\n" % (target_meta,0o1000002))!=1 or \
            script.count("deposit %06o %012o\n" % (target_meta,0o1000003))!=1:
        raise ValueError("foreign target injection/repair deposit not unique")
    (work/"physical.ini").write_text(script,encoding="ascii")
    (work/"expected-v1906.txt").write_text(
        "source_meta %06o\ntarget_meta %06o\nprocess_table %06o\n"
        "uarea %06o\nparent_gate %06o\ntarget_call %06o\n"
        "transition_clear %06o\nsource_return %06o\nservice_return %06o\n" %
        (source_meta,target_meta,table,uarea,parent_gate,target_call,
         clear_pc,source_return,service_return),encoding="ascii")
    print("v1906: PURE %06o, table %06o, private uarea %06o" %
          (pure_base,table,uarea))
    print("v1906: original native target-free %06o and transition %06o" %
          (target_call,clear_pc))


if __name__ == "__main__":
    if len(sys.argv)!=6:
        raise SystemExit("usage: prepare-physical-v1906.py kit build probe work prefix")
    try:
        prepare(*(Path(x) for x in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1906 physical controller: " + str(exc))
