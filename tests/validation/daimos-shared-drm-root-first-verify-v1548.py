#!/usr/bin/env python3
"""Accept only actual root-first Type-236 PI2 faults with owned swap.

Real linked symbols, console and post-HALT simulator memory are required.
The witness arm is created only on an uncached selected-root D6FS read.
"""
from pathlib import Path
import re
import sys


def symbol(mapping, name):
    matches = re.findall(r"(?m)^" + re.escape(name) +
                         r"\s+([0-7]{6})\s*$", mapping)
    if len(matches) != 1:
        raise AssertionError("missing linked symbol " + name)
    return int(matches[0], 8)


def word(post, addr, name):
    pattern = r"(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$" % addr
    matches = re.findall(pattern, post)
    if len(matches) != 1:
        raise AssertionError("missing/ambiguous physical word " + name)
    return int(matches[0], 8)


FIELDS = (
    "daimos_v1511_device_errors",
    "daimos_v1548_root_arm_count",
    "daimos_v1548_owner_at_arm",
    "backstore_enabled",
    "backstore_blocks_used",
    "device_region_map",
    "volume_data_blocks",
    "vfs_namespace_root",
)


def verify(mapping, boot, console, raw, source, driver):
    start = symbol(mapping, "kcore_critical_device_lost_v1515")
    root_pc, swap_pc = start + 3, start + 7
    halts = re.findall(r"HALT instruction, PC: ([0-7]{6})", console)
    raw_halts = re.findall(r"HALT instruction, PC: ([0-7]{6})", raw)
    if len(halts) != 1 or len(raw_halts) != 1 or (
            int(halts[0],8) != root_pc or int(raw_halts[0],8) != root_pc):
        raise AssertionError("not unique real linked ROOT HALT")
    if int(halts[0],8) == swap_pc or "FAIL_" in console:
        raise AssertionError("swap HALT or userspace error")
    if re.search(r"(?m)^deposit SW 3\s*$", boot) is None:
        raise AssertionError("not the selected DRM root boot")
    if re.search(r"(?m)^attach -q dr0 \S+/drum/dsk0\.dsk\s*$", boot) is None:
        raise AssertionError("root DR0 physical image not attached")
    post = raw.split("HALT instruction, PC:", 1)[1]
    values = {name:word(post,symbol(mapping,name),name) for name in FIELDS}
    if values["daimos_v1511_device_errors"] != 1:
        raise AssertionError("physical PI2 error count is not exactly one")
    if values["daimos_v1548_root_arm_count"] != 1:
        raise AssertionError("no single real root cache miss was armed")
    used = values["backstore_blocks_used"]
    if (used == 0 or values["backstore_enabled"] != 1 or
            values["daimos_v1548_owner_at_arm"] != used):
        raise AssertionError("BACKSTORE owner not retained at ROOT HALT")
    if values["device_region_map"] >> 18 != 0o400000:
        raise AssertionError("BACKSTORE is not DRM236 on root set")
    if values["volume_data_blocks"] == 0:
        raise AssertionError("BACKSTORE did not use mapped VOLUME")
    if values["vfs_namespace_root"] != 0o60101000000:
        raise AssertionError("root provider/mount is not D6FS 1")

    for text in ("d6fs_reader_get_block:",
                 "jumpn   1,d6fs_get_block_cache_hit",
                 "skipn   backstore_blocks_used",
                 "movem   1,daimos_v1548_owner_at_arm",
                 "setom   daimos_v1511_this_read",
                 "pushj   17,fs_backing_read",
                 "pushj   17,kcore_root_fs_io_failure_v1538"):
        if text not in source:
            raise AssertionError("real root path or test arm missing: " + text)
    for text in ("drm236_pi_handler:",
                 "daimos_v1511_target_descriptor",
                 "aos     daimos_v1511_device_errors",
                 "jrst    drm236_pi_error"):
        if text not in driver:
            raise AssertionError("selected descriptor PI2 path missing: " + text)
    samples = re.findall(
        r"v1541 sample=\d+ .+ pi2_device_errors=(\d+)", raw)
    if len(samples) < 2 or any(int(v) != 0 for v in samples):
        raise AssertionError("missing clean pre-fault PI2 history")
    return root_pc,values,len(samples)


def mutations(data):
    mapping, boot, console, raw, source, driver = data
    root_pc = symbol(mapping,"kcore_critical_device_lost_v1515") + 3
    address = {name:symbol(mapping,name) for name in FIELDS}

    def patch_word(text, name, new):
        addr = address[name]
        head,post = text.split("HALT instruction, PC:",1)
        expr = r"(?m)^(?:sim>\s*)?0*%o:\s*[0-7]{1,12}\s*$" % addr
        if len(re.findall(expr,post)) != 1:
            raise AssertionError("mutation did not find physical " + name)
        replacement = "sim> %o:\t%012o" % (addr,new)
        return head + "HALT instruction, PC:" + re.sub(expr,replacement,post,count=1)

    wrong_halt = "%06o" % (root_pc + 4)
    good_halt = "%06o" % root_pc
    tests = (
        ("wrong-halt-reason", (mapping,boot,
          console.replace(good_halt,wrong_halt,1),raw,source,driver)),
        ("duplicate-halt", (mapping,boot,
          console + "\nHALT instruction, PC: " + good_halt,raw,source,driver)),
        ("missing-raw-halt", (mapping,boot,console,
          raw.replace("HALT instruction, PC:","STOP PC:",1),source,driver)),
        ("no-pi2-error", (mapping,boot,console,
          patch_word(raw,"daimos_v1511_device_errors",0),source,driver)),
        ("root-arm-absent", (mapping,boot,console,
          patch_word(raw,"daimos_v1548_root_arm_count",0),source,driver)),
        ("owner-at-arm-lost", (mapping,boot,console,
          patch_word(raw,"daimos_v1548_owner_at_arm",0),source,driver)),
        ("owner-at-halt-lost", (mapping,boot,console,
          patch_word(raw,"backstore_blocks_used",0),source,driver)),
        ("wrong-backing-controller", (mapping,boot,console,
          patch_word(raw,"device_region_map",0),source,driver)),
        ("mapper-missing", (mapping,boot,console,
          patch_word(raw,"volume_data_blocks",0),source,driver)),
        ("root-not-published", (mapping,boot,console,
          patch_word(raw,"vfs_namespace_root",0),source,driver)),
        ("root-source-bypassed", (mapping,boot,console,raw,
          source.replace("setom   daimos_v1511_this_read",
                         "setzm   daimos_v1511_this_read",1),driver)),
        ("driver-pi2-bypassed", (mapping,boot,console,raw,source,
          driver.replace("aos     daimos_v1511_device_errors",
                         "setzm   daimos_v1511_device_errors",1))),
        ("false-pre-fault", (mapping,boot,console,
          raw.replace("pi2_device_errors=0","pi2_device_errors=1",1),
          source,driver)),
    )
    for name,values in tests:
        try:
            verify(*values)
        except AssertionError:
            print("PASS v1548: rejected " + name)
        else:
            raise AssertionError("accepted forged root-loss witness " + name)
    return len(tests)


def main():
    args = list(sys.argv[1:])
    self_test = "--self-test" in args
    if self_test:
        args.remove("--self-test")
    if len(args) != 6:
        raise SystemExit("usage: verifier-v1548 [--self-test] "
                         "MAP BOOT CONSOLE RAW ROOT_SOURCE DRIVER_SOURCE")
    data = tuple(Path(f).read_text(errors="replace") for f in args)
    pc,values,history = verify(*data)
    print("PASS v1548: actual ROOT physical HALT at %06o" % pc)
    print("PASS v1548: owned=%06o at arm and HALT, "
          "pi2=%d pre-fault-samples=%d" %
          (values["backstore_blocks_used"],
           values["daimos_v1511_device_errors"],history))
    if self_test:
        print("PASS v1548: %d corrupted witnesses rejected" % mutations(data))


if __name__ == "__main__":
    main()
