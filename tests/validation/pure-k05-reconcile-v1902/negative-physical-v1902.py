#!/usr/bin/env python3
"""Independently mutate original 48K PDP6 v1902 physical witnesses."""

from pathlib import Path
import re
import subprocess
import sys


def replace_stage(text,stage,addr,old,new):
    begin="V1902_STAGE_%s\n" % stage
    end="V1902_END_%s\n" % stage
    if text.count(begin)!=1 or text.count(end)!=1:
        raise ValueError("original physical stage not unique: "+stage)
    head,rest=text.split(begin,1)
    body,tail=rest.split(end,1)
    pattern=r"(?m)^(%o:\s*)([0-7]{12})$" % addr
    vals=re.findall(pattern,body)
    if not vals or any(int(v,8)!=old for _,v in vals):
        raise ValueError("original physical word drift: %06o"%addr)
    body=re.sub(pattern,lambda m:m.group(1)+"%012o"%new,body)
    return head+begin+body+end+tail


def run(kit,build,work):
    p=work/"physical.clean"
    source=p.read_bytes()
    text=source.decode("ascii")
    fields=dict((k,int(v,8)) for k,v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)$",
        (work/"expected-v1902.txt").read_text("ascii")))
    mm=0o24251
    meta=fields["source_meta"]
    controls=[
        ("lost-native-MM-refusal",
         text.replace("V1902_REAL_MM_FREE_REFUSED\n1:\t777777777773",
                      "V1902_REAL_MM_FREE_REFUSED\n1:\t000000000000",1),
         "original native PACKED mm_free did not return -5"),
        ("missing-source-pin",
         text.replace("V1902_TEST_ONLY_PIN\n%o:\t%012o" %
                      (meta,fields["source_pin1"]),
                      "V1902_TEST_ONLY_PIN\n%o:\t%012o" %
                      (meta,fields["source_pin0"]),1),
         "original source pin not genuinely installed/held"),
        ("fake-MM-free-during-refusal",
         replace_stage(text,"NATIVE_REFUSED",mm,18,17),
         "original dual owner/pin not preserved at refusal"),
        ("fake-source-pin-drop-at-refusal",
         replace_stage(text,"NATIVE_REFUSED",meta,
                       fields["source_pin1"],fields["source_pin0"]),
         "original dual owner/pin not preserved at refusal"),
        ("fake-MM-free-before-parent-HB",
         replace_stage(text,"PINNED_HB",mm,18,17),
         "original dual owner/pin not preserved at held pin"),
        ("fake-source-pin-drop-before-parent-HB",
         replace_stage(text,"PINNED_HB",meta,
                       fields["source_pin1"],fields["source_pin0"]),
         "original dual owner/pin not preserved at held pin"),
        ("fake-invalid-MM-count-after-release",
         replace_stage(text,"RETRY_HB",mm,18,16),
         "unexpected original MM owner count after release"),
    ]
    table=fields.get("process_table",0)
    if table:
        post_meta=0o46635400401
        held_meta=0o46635600401
        controls.extend((
            ("falsified-stuck-TRANSITION-after-pin-release",
             replace_stage(text,"POST_PIN_HB",table+9,
                           post_meta,held_meta),
             "original slot3 TRANSITION did not unlock/retry"),
            ("falsified-no-native-target-rollback",
             replace_stage(text,"POST_PIN_HB",mm,17,18),
             "original slot3 scratch rollback and retry not proved"),
            ("falsified-source-pin-not-released",
             replace_stage(text,"POST_PIN_HB",meta,
                           fields["source_pin0"],fields["source_pin1"]),
             "original slot3 scratch rollback and retry not proved"),
            ("falsified-no-new-FULL-retry",
             replace_stage(text,"RETRY_HB",mm,18,17),
             "original slot3 scratch rollback and retry not proved"),
            ("falsified-private-uarea-reallocation",
             replace_stage(text,"RETRY_HB",table+9,
                           held_meta,held_meta+(1<<18)),
             "original slot3 TRANSITION did not unlock/retry"),
        ))
    verify=kit/"tests/validation/pure-k05-reconcile-v1902/verify-physical-v1902.py"
    for name,mutated,error in controls:
        if mutated==text:
            raise ValueError("inert negative control: "+name)
        p.write_text(mutated,encoding="ascii")
        try:
            r=subprocess.run([sys.executable,str(verify),str(kit),
                str(build),str(work)],capture_output=True,text=True)
        finally:
            p.write_bytes(source)
        if r.returncode==0 or error not in r.stderr:
            raise ValueError("unsafe physical %s not rejected: %s"%
                             (name,r.stderr.strip()))
        print("PASS v1902: independently corrupted physical %s rejected"%name)
    print("PASS v1902: %d original 48K physical negative controls"%len(controls))


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1902.py kit build physical-work")
    try:
        run(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,UnicodeError) as e:
        raise SystemExit("FAIL v1902 original physical negatives: "+str(e))
