#!/usr/bin/env python3
"""Stage full D6FS with native DAS and independent host object goldens."""

import importlib.util
import os
from pathlib import Path
import sys


def load_module(source, name):
    spec = importlib.util.spec_from_file_location(name, source)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


def main():
    if len(sys.argv) != 8:
        raise SystemExit("usage: build_root_v1405.py DAIMOS TESTKIT WORK "
                         "NATIVE_KCC NATIVE_DAS OBJECTS FIXTURES")
    repo, testkit, work, kcc, das, objects, fixtures = [
        Path(x).resolve() for x in sys.argv[1:]]
    old = load_module(
        testkit / "tests/validation/d6codec-fulldist-v1371" /
        "build_full_root_v1371.py", "fullroot_v1405")
    previous = load_module(
        testkit / "tests/validation/kcc-native-refresh-v1373" /
        "build_root_v1373.py", "kccroot_v1405")
    v1370 = Path(os.environ["TMPDIR"]) / "d6codec-fullboot-v1370"
    pairs = old.root_inventory(repo, work, v1370 / "userland-build")
    codec = old.load_codec(testkit)
    tools = {
        "/OPTION/BASE/EXEC/KCC": kcc / "KCC.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KCPP": kcc / "KCPP.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KPARSE": kcc / "KPARSE.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KGEN": kcc / "KGEN.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KOPT": kcc / "KOPT.dxr",
        "/OPTION/BASE/EXEC/DAS": das / "das.dxr",
        "/OPTION/BASE/LIBEXEC/DAS/DAS1": das / "das1.dxr",
        "/OPTION/BASE/LIBEXEC/DAS/DAS2": das / "das2.dxr",
    }
    seen = set()
    changed = []
    for opt, value in pairs:
        if opt == "-f":
            target, source, mode, kind = value.rsplit(":", 3)
            if target in tools:
                if target in seen or mode != "555" or kind != "dxr":
                    raise ValueError("incorrect normal tool entry: " + value)
                source = tools[target]
                codec.unpack_original(codec.load(source))
                seen.add(target)
                value = ":".join((target, str(source), mode, kind))
        changed.append((opt, value))
    if seen != set(tools):
        raise ValueError("missing normal tool entries: " +
                         repr(set(tools) - seen))
    grouped = old.stage_grouped(repo, testkit, work,
                                v1370 / "userland-build", changed)

    extra = {
        "/CONFIG/V1403.C": objects / "main-v1403.s6rec",
        "/CONFIG/V1403-CRT0.DOBJ": objects / "crt0.dobj",
        "/CONFIG/V1403-SYSCALL.DOBJ": objects / "syscall.dobj",
        "/CONFIG/V1403-MAIN.DOBJ": objects / "main.dobj",
        "/CONFIG/V1403-HOST.DXR": objects / "host-v1403.dxr",
    }
    for stem in ("call-main", "call-provider", "data-main",
                 "data-provider", "local-main"):
        label = stem.replace("-", "").upper()
        for ext, source_ext in (("C", "s6rec"), ("A7", "a7"),
                                ("DOBJ", "dobj")):
            target = "/CONFIG/V1405-%s.%s" % (label, ext)
            extra[target] = fixtures / (stem + "-v1405." + source_ext)
    for stem in ("call", "data", "local"):
        extra["/CONFIG/V1405-%s-GOLD.DXR" % stem.upper()] = (
            fixtures / (stem + "-gold-v1405.dxr"))
    present = {v.split(":", 1)[0] for opt, v in grouped if opt == "-f"}
    for target, source in extra.items():
        if target in present or not source.is_file():
            raise ValueError("missing or duplicate DOBJ1 fixture: " + target)
        grouped.append(("-f", ":".join((
            target, str(source), "644", "binwords"))))

    bindir = Path(os.environ["PDP10_PREFIX"]) / "bin"
    disk = work / "disk-pristine-v1405"
    disk.mkdir(parents=True, exist_ok=True)
    previous.execute([bindir / "mkdsk", "-n", "4", "-m", "clean",
                      "-p", v1370 / "grouped-kinit-v1370.compressed.words",
                      "-o", disk, "--d6fs-layout", "--logstore-blocks", "0400",
                      "--swap-tail-blocks", "0400", "--spare-blocks", "0",
                      "--member-sectors", "0130000,0130000,0130000,0130000"])
    previous.execute([bindir / "mkd6fs", "-n", "4", "-d", disk,
                      *[arg for pair in grouped for arg in pair]],
                     work / "mkd6fs-v1405.log")
    previous.execute([bindir / "logstore", "-n", "4", "-d", disk,
                      "--init"])
    previous.execute([bindir / "d6fsck", "-n", "4", "-d", disk])
    print("V1405_ROOT_PASS replacements=8 extra=23 inventory=237")


if __name__ == "__main__":
    main()
