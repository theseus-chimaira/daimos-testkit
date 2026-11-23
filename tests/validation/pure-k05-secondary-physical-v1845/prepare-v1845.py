#!/usr/bin/env python3
"""Create a disposable, source-matched physical PURE MRES base probe."""

from pathlib import Path
import re
import sys
import subprocess


def symbols(path):
    values = {}
    for line in path.read_text(encoding="ascii").splitlines():
        fields = line.split()
        if len(fields) == 2 and re.fullmatch(r"[0-7]+", fields[1]):
            values[fields[0]] = int(fields[1], 8)
    return values


def private_boot(build, out):
    text = (build / "boot.ini").read_text(encoding="ascii")
    if text.count("set cpu 48k\n") != 1:
        raise ValueError("not the 48K PDP-6 source-built boot")
    for unit in range(4):
        prefix = "attach -q dtc%d " % unit
        found = [x[len(prefix):] for x in text.splitlines()
                 if x.startswith(prefix)]
        if len(found) != 1:
            raise ValueError("missing unique DTC%d tape" % unit)
        path = out / "media" / ("dtc%d.tap" % unit)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(Path(found[0]).read_bytes())
        text = text.replace(prefix + found[0], prefix + str(path), 1)
    text = "\n".join(line for line in text.splitlines()
                     if not line.startswith(("attach -q dsk", "attach -q dr")))
    return text + "\n"


def probe(build, out):
    core = symbols(build / "kcore.map")
    pure = symbols(build / "pure-mres-v1612.map")
    for symbol in ("proc_swap_reclaim", "mm_core_words"):
        if symbol not in core:
            raise ValueError("missing original KCORE symbol: " + symbol)
    if "proc_pure_mres_reclaim_v1612" not in pure:
        raise ValueError("missing original PURE MRES service")
    source = (build / "../user/init-v1614.c").resolve().read_text(
        encoding="ascii")
    children = re.findall(r"(?m)^#define P14_CHILDREN\s+([0-9]+)U$",
                          source)
    if len(children) != 1 or not 1 <= int(children[0]) <= 9:
        raise ValueError("cannot identify exact physical child fixture")
    marker = "a" * int(children[0]) + "x[B"
    text = private_boot(build, out)
    tail = ("expect \"%s\"\n" % marker +
            "go 020\n"
            "echo V1845_ORIGINAL_JRST\n"
            "examine %06o\n" % core["proc_swap_reclaim"] +
            "examine %06o\n" % core["mm_core_words"] +
            "echo V1845_END_JRST\n"
            "exit\n")
    if text.count("go 020\nexit\n") != 1:
        raise ValueError("boot script entry drifted")
    (out / "probe.ini").write_text(text.replace(
        "go 020\nexit\n", tail, 1), encoding="ascii")
    print("v1845: original CORE JRST probe at %06o" %
          core["proc_swap_reclaim"])


def source_v1845(original, output):
    text = original.read_text(encoding="ascii")
    header = "#define P14_CHILDREN         6U"
    if text.count(header) != 1 or text.count(
            "denied = p14_spawn(rd, 1U);") != 1:
        raise ValueError("v1643 original guest geometry drift")
    text = text.replace(header, "#define P14_CHILDREN         5U", 1)
    text = text.replace("Seventh RUN", "Sixth RUN")
    output.write_text(text, encoding="ascii")


def read_probe(build, trace):
    core = symbols(build / "kcore.map")
    pure = symbols(build / "pure-mres-v1612.map")
    text = trace.read_text(encoding="ascii")
    if text.count("V1845_ORIGINAL_JRST\n") != 1 or \
            text.count("V1845_END_JRST\n") != 1:
        raise ValueError("missing original physical MRES base observation")
    capture = text.split("V1845_ORIGINAL_JRST\n", 1)[1].split(
        "V1845_END_JRST\n", 1)[0]
    address = core["proc_swap_reclaim"]
    found = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address,
                       capture)
    if len(found) != 1:
        raise ValueError("missing unique original physical JRST")
    instruction = int(found[0], 8)
    if instruction >> 27 != 0o254:
        raise ValueError("reclaim trampoline is not installed JRST")
    entry = instruction & 0o777777
    base = entry - pure["proc_pure_mres_reclaim_v1612"]
    if not 0o20000 < base < 0o140000:
        raise ValueError("invalid installed PURE MRES base")
    print("v1845: current physical PURE base %06o, JRST target %06o" %
          (base, entry))
    print("V1845_PURE_BASE=%06o" % base)
    return base


def source_words(build, dxrcheck):
    image = subprocess.check_output([str(dxrcheck), "-d",
                                     str(build / "pure-mres-v1612.dxr")],
                                    encoding="ascii")
    result = {}
    for addr, data in re.findall(
            r"(?m)^IMAGE\s+([0-7]{6})\s+([0-7]{12})\s*$", image):
        location = int(addr, 8)
        if location in result:
            raise ValueError("duplicated PURE instruction")
        result[location] = int(data, 8)
    return result


def snapshot(core, label):
    commands = "echo V1845_STAGE_%s\n" % label
    for name in ("proc_current_slot", "proc_high_slot", "mm_extent_count",
                 "mm_arena_count", "vfs_namespace_root", "dtfs_media_base",
                 "vfs_mount_root_base"):
        commands += "examine %06o\n" % core[name]
    commands += "examine %06o-%06o\n" % (
        core["mm_arenas"], core["mm_arenas"] + 7)
    commands += "examine %06o-%06o\n" % (
        core["mm_extents"], core["mm_extents"] + 95)
    return commands + "echo V1845_END_%s\n" % label


def physical(build, out, base, dxrcheck):
    core = symbols(build / "kcore.map")
    pure = symbols(build / "pure-mres-v1612.map")
    words = source_words(build, dxrcheck)
    call_target = pure["proc_pure_ram_restore_v1391"]
    service_start = pure["proc_pure_mres_service_v1612"]
    # The real linked service contains one direct PUSHJ to the original
    # bounded FULL transaction. Its following instruction is the actual
    # return breakpoint, never a position copied from an old build.
    calls = [addr for addr in words
             if service_start <= addr < service_start + 0o400 and
             words[addr] == (0o260740000000 | call_target)]
    if len(calls) != 1:
        raise ValueError("missing unique compiled service FULL call")
    loader = pure["exec_image_full_bounded_v1391"]
    if loader not in words:
        raise ValueError("missing compiled original bounded FULL loader")
    if not 0 < base + loader < 0o140000:
        raise ValueError("original physical FULL loader exceeds core")
    source = (build / "../user/init-v1614.c").resolve().read_text(
        encoding="ascii")
    found = re.findall(r"(?m)^#define P14_CHILDREN\s+([0-9]+)U$",
                       source)
    if len(found) != 1 or found[0] != "5":
        raise ValueError("v1845 must use exactly five original child paths")
    ini = private_boot(build, out)
    head = ini.replace("go 020\nexit\n", "")
    if head == ini:
        raise ValueError("original simulator entrypoint has changed")
    tail = 'expect "aaaaax[B"\ngo 020\n' + snapshot(core, "B")
    tail += 'expect "[A"\ncont\n' + snapshot(core, "A")
    tail += 'break %06o\ncont\n' % (base + loader)
    tail += 'echo V1845_BOUNDED_FULL_SECONDARY\n'
    tail += 'examine %06o\n' % (base + loader)
    for ac in range(1, 5):
        tail += 'examine %o\n' % ac
    tail += snapshot(core, "FULL_PINNED")
    tail += 'nobreak\ndetach dtc3\n'
    tail += 'echo V1845_DTC3_DETACHED\nshow dtc3\n'
    tail += 'echo V1845_END_DTC3_DETACHED\n'
    tail += 'break %06o\ncont\n' % (base + calls[0] + 1)
    tail += 'echo V1845_FAILED_FULL_RETURN\n'
    for ac in range(1, 5):
        tail += 'examine %o\n' % ac
    tail += snapshot(core, "ROLLED_BACK")
    tail += 'nobreak\n'
    tail += 'attach -q dtc3 %s\n' % (out / "media/dtc3.tap")
    tail += 'echo V1845_SAME_DTC3_REATTACHED\nshow dtc3\n'
    tail += 'echo V1845_END_DTC3_REATTACHED\n'
    tail += 'expect "Z"\ncont\n' + snapshot(core, "Z")
    tail += 'cont\nexit\n'
    (out / "physical.ini").write_text(head + tail, encoding="ascii")
    (out / "expected-v1845.txt").write_text(
        "loader %06o\nloader_opcode %012o\nservice_return %06o\nbase %06o\n" %
        (base + loader, words[loader], base + calls[0] + 1, base),
        encoding="ascii")
    print("v1845: physical FULL %06o, service return %06o" %
          (base + loader, base + calls[0] + 1))


def main(argv):
    if len(argv) not in (4, 6):
        raise SystemExit("usage: prepare-v1845.py probe|read|source|physical ...")
    op, build, output = argv[1], Path(argv[2]), Path(argv[3])
    if op == "probe":
        output.mkdir(parents=True, exist_ok=True)
        probe(build, output)
    elif op == "read":
        read_probe(build, output)
    elif op == "source":
        source_v1845(build, output)
    elif op == "physical" and len(argv) == 6:
        output.mkdir(parents=True, exist_ok=True)
        physical(build, output, int(argv[4], 8), Path(argv[5]))
    else:
        raise SystemExit("unknown v1845 operation")


if __name__ == "__main__":
    main(sys.argv)
