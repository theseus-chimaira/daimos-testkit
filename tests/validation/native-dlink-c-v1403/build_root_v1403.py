#!/usr/bin/env python3
"""Stage host DOBJ link fixtures and native KCC/DAS in a grouped test root."""

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
                         "NATIVE_KCC NATIVE_DAS FIXTURES")
    repo, testkit, work, kcc, das, fixtures = [
        Path(x).resolve() for x in sys.argv[1:]]
    v1370 = Path(os.environ["TMPDIR"]) / "d6codec-fullboot-v1370"
    old = load_module(
        testkit / "tests/validation/d6codec-fulldist-v1371" /
        "build_full_root_v1371.py", "fullroot_v1403")
    build = load_module(
        testkit / "tests/validation/kcc-native-refresh-v1373" /
        "build_root_v1373.py", "kccroot_v1403")
    pairs = old.root_inventory(repo, work, v1370 / "userland-build")
    codec = old.load_codec(testkit)

    replacements = {
        "/OPTION/BASE/EXEC/KCC": kcc / "KCC.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KCPP": kcc / "KCPP.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KPARSE": kcc / "KPARSE.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KGEN": kcc / "KGEN.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KOPT": kcc / "KOPT.dxr",
        "/OPTION/BASE/EXEC/DAS": das / "das.dxr",
        "/OPTION/BASE/LIBEXEC/DAS/DAS1": das / "das1.dxr",
        "/OPTION/BASE/LIBEXEC/DAS/DAS2": das / "das2.dxr",
    }
    changed = []
    seen = set()
    for option, spec in pairs:
        if option == "-f":
            target, host, mode, kind = spec.rsplit(":", 3)
            if target in replacements:
                if target in seen or mode != "555" or kind != "dxr":
                    raise ValueError("invalid native replacement: " + spec)
                source = replacements[target]
                codec.unpack_original(codec.load(source))
                spec = ":".join((target, str(source), mode, kind))
                seen.add(target)
        changed.append((option, spec))
    if seen != set(replacements):
        raise ValueError("missing normal distribution tools: " +
                         repr(set(replacements) - seen))
    grouped = old.stage_grouped(repo, testkit, work,
                                v1370 / "userland-build", changed)

    extra = {
        "/CONFIG/V1403-MAIN.C": fixtures / "native-main-v1403.s6rec",
        "/CONFIG/V1403-MAIN-GOLD.A7": fixtures / "native-main-v1403.a7",
        "/CONFIG/V1403-MAIN.DOBJ": fixtures / "native-main-v1403.dobj",
        "/CONFIG/V1403-CRT0.DOBJ": fixtures / "crt0-v1403.dobj",
        "/CONFIG/V1403-SYSCALL.DOBJ": fixtures / "syscall-v1403.dobj",
        "/CONFIG/V1403-SYSH.DOBJ": fixtures / "syscall_helpers-v1403.dobj",
        "/CONFIG/V1403-GOLD.DXR": fixtures / "native-gold-v1403.dxr",
    }
    extras = {part.split(":", 1)[0] for opt, part in grouped
              if opt == "-f"}
    for target, host in extra.items():
        if target in extras or not host.is_file():
            raise ValueError("invalid fixture: " + target)
        grouped.append(("-f", ":".join(
            (target, str(host), "644", "binwords"))))
    bindir = Path(os.environ.get("PDP10_PREFIX", str(
        Path.home() / "cross"))) / "bin"
    disk = work / "disk-pristine-v1403"
    disk.mkdir(parents=True, exist_ok=True)
    build.execute([bindir / "mkdsk", "-n", "4", "-m", "clean",
                   "-p", v1370 / "grouped-kinit-v1370.compressed.words",
                   "-o", disk, "--d6fs-layout", "--logstore-blocks", "0400",
                   "--swap-tail-blocks", "0400", "--spare-blocks", "0",
                   "--member-sectors", "0130000,0130000,0130000,0130000"])
    build.execute([bindir / "mkd6fs", "-n", "4", "-d", disk,
                   *[x for pair in grouped for x in pair]],
                  work / "mkd6fs-v1403.log")
    build.execute([bindir / "logstore", "-n", "4", "-d", disk, "--init"])
    build.execute([bindir / "d6fsck", "-n", "4", "-d", disk])
    print("V1403_ROOT_PASS replacements=8 extra=7 full_inventory=237")


if __name__ == "__main__":
    main()
