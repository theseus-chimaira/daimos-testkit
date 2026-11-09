#!/usr/bin/env python3
"""Stage native KCC/DAS/DLINK with independently produced DOBJ1 inputs."""

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
    if len(sys.argv) != 7:
        raise SystemExit("usage: build_root_v1403.py DAIMOS TESTKIT WORK "
                         "NATIVE_KCC NATIVE_DAS OBJECTS")
    repo, testkit, work, kcc, das, objects = [
        Path(x).resolve() for x in sys.argv[1:]]
    old = load_module(
        testkit / "tests/validation/d6codec-fulldist-v1371" /
        "build_full_root_v1371.py", "fullroot_v1403")
    previous = load_module(
        testkit / "tests/validation/kcc-native-refresh-v1373" /
        "build_root_v1373.py", "kccroot_v1403")
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
    # Optional versioned DAS1/DAS2 symbol-transport fixture.  It does
    # not alter the accepted v1403 inventory unless explicitly supplied.
    metadata_fixture = os.environ.get("V1405_OBJECT_METADATA_A7")
    if metadata_fixture:
        extra["/CONFIG/V1405-METADATA.A7"] = Path(metadata_fixture)
    # Optional v1407 C89 ABI execution comparison.  These are complete
    # host-linked DXR fixtures, not input objects or scratch text.
    executable_fixture = {}
    for env_name, target in (
            ("V1407_BEFORE_DXR", "/SYSTEM/EXEC/V1407OLD"),
            ("V1407_AFTER_DXR", "/SYSTEM/EXEC/V1407NEW"),
            ("V1410_NOOPT_DXR", "/SYSTEM/EXEC/V1410NOOPT")):
        value = os.environ.get(env_name)
        if value:
            executable_fixture[target] = Path(value)
    present = {v.split(":", 1)[0] for opt, v in grouped if opt == "-f"}
    for target, source in extra.items():
        if target in present or not source.is_file():
            raise ValueError("missing or duplicate DOBJ1 fixture: " + target)
        grouped.append(("-f", ":".join((
            target, str(source), "644", "binwords"))))
    for target, source in executable_fixture.items():
        if target in present or not source.is_file():
            raise ValueError("missing or duplicate v1407 executable: " + target)
        codec.unpack_original(codec.load(source))
        grouped.append(("-f", ":".join((
            target, str(source), "555", "dxr"))))

    bindir = Path(os.environ["PDP10_PREFIX"]) / "bin"
    disk = work / "disk-pristine-v1403"
    disk.mkdir(parents=True, exist_ok=True)
    previous.execute([bindir / "mkdsk", "-n", "4", "-m", "clean",
                      "-p", v1370 / "grouped-kinit-v1370.compressed.words",
                      "-o", disk, "--d6fs-layout", "--logstore-blocks", "0400",
                      "--swap-tail-blocks", "0400", "--spare-blocks", "0",
                      "--member-sectors", "0130000,0130000,0130000,0130000"])
    previous.execute([bindir / "mkd6fs", "-n", "4", "-d", disk,
                      *[arg for pair in grouped for arg in pair]],
                     work / "mkd6fs-v1403.log")
    previous.execute([bindir / "logstore", "-n", "4", "-d", disk,
                      "--init"])
    previous.execute([bindir / "d6fsck", "-n", "4", "-d", disk])
    print("V1403_ROOT_PASS replacements=8 objects=5 inventory=237")


if __name__ == "__main__":
    main()
