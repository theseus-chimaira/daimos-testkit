#!/usr/bin/env python3
"""Reject fake 48K original MM free/owner or premature retry unlock."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def block(text, a, b):
    a += "\n"
    b += "\n"
    if text.count(a) != 1 or text.count(b) != 1:
        raise ValueError("missing unique physical stage: " + a.strip())
    return text.split(a,1)[1].split(b,1)[0]


def word(text, addr):
    vals = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr,text)
    # The original v1845 snapshot intentionally examines certain
    # source-backed scalar words twice (individual and range). Both
    # readings must agree; treating the duplicate as an absent word
    # would incorrectly reject a valid physical transcript.
    if not vals or len(set(vals)) != 1:
        raise ValueError("missing/ambiguous original physical word %06o"%addr)
    return int(vals[0],8)


def verify(kit, build, work):
    expected_images = (
        ("kcore.dxr", "aa80ea2d98778298c13ae96de76c52815cfd40ad5486030e5056b436f85072f5"),
        ("pure-mres-v1612.dxr", "2dd7b7f7340d5b1b9542a97d0e8aca8478ac32afc3c555f0ae1ab38d0cd39a6b"),
    )
    for name, digest in expected_images:
        if hashlib.sha256((build/name).read_bytes()).hexdigest() != digest:
            raise ValueError("not the accepted source-built original 48K v1902 "+name)
    trace = (work/"physical.clean").read_text(encoding="ascii")
    expect = dict((k,int(v,8)) for k,v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)$",
        (work/"expected-v1902.txt").read_text(encoding="ascii")))
    original = runpy.run_path(str(kit/"tests/validation/"
                  "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = original["symbols"](build/"kcore.map")
    pin = block(trace,"V1902_TEST_ONLY_PIN","V1902_END_TEST_ONLY_PIN")
    release = block(trace,"V1902_EXTERNAL_PIN_RELEASE","V1902_END_PIN_RELEASE")
    refused = block(trace,"V1902_STAGE_NATIVE_REFUSED","V1902_END_NATIVE_REFUSED")
    failed = block(trace,"V1902_STAGE_FAILED_FULL","V1902_END_FAILED_FULL")
    hb = block(trace,"V1902_STAGE_PINNED_HB","V1902_END_PINNED_HB")
    later = block(trace,"V1902_STAGE_RETRY_HB","V1902_END_RETRY_HB")
    meta = expect["source_meta"]
    if word(pin,meta) != expect["source_pin1"] or \
            word(release,meta) != expect["source_pin1"]:
        raise ValueError("original source pin not genuinely installed/held")
    native_reply = trace.split("V1902_REAL_MM_FREE_REFUSED\n",1)
    if trace.count("V1902_REAL_MM_FREE_REFUSED\n") != 1 or \
            word(native_reply[1].split("V1902_STAGE_NATIVE_REFUSED\n",1)[0],
                 1) != 0o777777777773:
        raise ValueError("original native PACKED mm_free did not return -5")
    for stage,name in ((refused,"refusal"),(failed,"failed FULL"),
                       (hb,"held pin")):
        if word(stage,core["mm_extent_count"]) != 18 or \
                word(stage,meta) != expect["source_pin1"]:
            raise ValueError("original dual owner/pin not preserved at "+name)
    if word(hb,core["proc_current_slot"]) != 1:
        raise ValueError("resident parent did not execute original first HB")
    # An original 'HB' is emitted in user mode, but the SIMH expect
    # breakpoint may stop after PI6 has already switched to slot0.
    # Do not misidentify that legal context switch as a missing HB.
    if word(later,core["proc_current_slot"]) not in (0,1):
        raise ValueError("retry HB has an unexpected scheduler owner")
    if word(later,core["mm_extent_count"]) not in (17,18):
        raise ValueError("unexpected original MM owner count after release")
    table = expect.get("process_table",0)
    if table:
        post = block(trace,"V1902_STAGE_POST_PIN_HB","V1902_END_POST_PIN_HB")
        slot3 = table + 9
        first_meta = word(hb,slot3)
        post_meta = word(post,slot3)
        retry_meta = word(later,slot3)
        if word(hb,core["proc_table"]) != table or \
                word(post,core["proc_table"]) != table or \
                word(later,core["proc_table"]) != table:
            raise ValueError("original physical relocated process table drift")
        if not (first_meta & 0o200000) or \
                (post_meta & 0o200000) or \
                (first_meta & ~0o200000) != post_meta or \
                retry_meta != first_meta:
            raise ValueError("original slot3 TRANSITION did not unlock/retry")
        if word(post,core["mm_extent_count"]) != 17 or \
                word(later,core["mm_extent_count"]) != 18 or \
                word(post,meta) != expect["source_pin0"] or \
                word(later,meta) != expect["source_pin0"]:
            raise ValueError("original slot3 scratch rollback and retry not proved")
        for stage in (hb,post,later):
            if word(stage,slot3+1) != 0o10000000000 or \
                    (word(stage,slot3) >> 18) != (first_meta >> 18):
                raise ValueError("original saved slot3 u-area/VMbase changed")
        print("PASS v1902: original slot3 TRANSITION held -> CLEARED -> held")
        print("PASS v1902: native scratch PROCESS removed MM18 -> MM17; new FULL retry MM18")
        print("PASS v1902: original private u-area and PACKED source remain authoritative")
    print("PASS v1902: real original 48K PDP6 native PACKED free -5, exact MM18")
    print("PASS v1902: only test-only source pin modified, parent HBs continue")
    if table:
        print("v1902: scoped physical rollback and new FULL retry ACCEPTED; final EXIT/WAIT still OPEN")
    else:
        print("v1902 post-pin-release MM count=%d (first-stage observation only)" %
              word(later,core["mm_extent_count"]))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-physical-v1902.py kit build physical-work")
    try:
        verify(*(Path(a) for a in sys.argv[1:]))
    except (ValueError,OSError,KeyError,AssertionError) as e:
        raise SystemExit("FAIL v1902 original 48K physical recovery: "+str(e))
