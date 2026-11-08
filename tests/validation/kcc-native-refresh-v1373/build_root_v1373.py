#!/usr/bin/env python3
"""Build a complete grouped DAIMOS root with current-source KCC phases.

No standard file list or production Makefile is modified: expand the
live D6FS_ROOT_ARGS and replace only the five native compiler DXRs.
"""

import importlib.util
import os
from pathlib import Path
import subprocess
import sys


def load_previous(root):
    source = (root / "tests/validation/d6codec-fulldist-v1371" /
              "build_full_root_v1371.py")
    spec = importlib.util.spec_from_file_location("fullroot_v1371", source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def execute(argv, log=None):
    print("RUN", Path(str(argv[0])).name, "args", len(argv), flush=True)
    if log is None:
        subprocess.run([str(arg) for arg in argv], check=True)
    else:
        with Path(log).open("w") as output:
            subprocess.run([str(arg) for arg in argv], check=True,
                           stdout=output, stderr=subprocess.STDOUT)


def build(repo, testkit, work, new_native, reference_source):
    old = load_previous(testkit)
    v1370 = Path(os.environ["TMPDIR"]) / "d6codec-fullboot-v1370"
    v1371 = Path(os.environ["TMPDIR"]) / "d6codec-fulldist-v1371"
    userland = v1370 / "userland-build"
    pairs = old.root_inventory(repo, work, userland)
    codec = old.load_codec(testkit)

    replacements = {
        "/OPTION/BASE/EXEC/KCC": "KCC.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KCPP": "KCPP.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KPARSE": "KPARSE.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KGEN": "KGEN.dxr",
        "/OPTION/BASE/LIBEXEC/KCC/KOPT": "KOPT.dxr",
    }
    seen = set()
    changed = []
    for option, arg in pairs:
        if option != "-f":
            changed.append((option, arg))
            continue
        target, host, mode, fmt = arg.rsplit(":", 3)
        if target in replacements:
            if target in seen or mode != "555" or fmt != "dxr":
                raise ValueError("invalid native KCC inventory: " + arg)
            source = new_native / replacements[target]
            codec.unpack_original(codec.load(source))
            seen.add(target)
            arg = ":".join((target, str(source), mode, fmt))
        changed.append((option, arg))
    if seen != set(replacements):
        raise ValueError("incomplete current KCC root replacement")

    grouped = old.stage_grouped(repo, testkit, work, userland, changed)
    target_paths = {value.split(":", 1)[0] for option, value in grouped
                    if option == "-f"}
    expected_path = "/CONFIG/V1373-GOLD.A7"
    source_path = "/CONFIG/V1373.C"
    extras = ((source_path, reference_source[0], "644", "binwords"),
              (expected_path, reference_source[1], "644", "binwords"),
              ("/CONFIG/V1373-NESTED.C", reference_source[2], "644", "binwords"),
              ("/CONFIG/V1373-NESTED-GOLD.A7", reference_source[3], "644", "binwords"),
              ("/SYSTEM/EXEC/V1373ABI", reference_source[4], "555", "dxr"))
    for target, host, mode, fileformat in extras:
        if target in target_paths or not Path(host).is_file():
            raise ValueError("invalid KCC acceptance fixture: " + target)
        grouped.append(("-f", "%s:%s:%s:%s" % (target, host, mode, fileformat)))
    print("V1373_CURRENT_KCC_ROOT_PASS replacements=5 standard_files=237",
          flush=True)

    disk = work / "disk-pristine-v1373"
    disk.mkdir(parents=True, exist_ok=True)
    prefix = Path(os.environ.get("PDP10_PREFIX", str(Path.home() / "cross")))
    bindir = prefix / "bin"
    execute([bindir / "mkdsk", "-n", "4", "-m", "clean",
             "-p", v1370 / "grouped-kinit-v1370.compressed.words",
             "-o", disk, "--d6fs-layout", "--logstore-blocks", "0400",
             "--swap-tail-blocks", "0400", "--spare-blocks", "0",
             "--member-sectors", "0130000,0130000,0130000,0130000"])
    args = [part for pair in grouped for part in pair]
    execute([bindir / "mkd6fs", "-n", "4", "-d", disk, *args],
            work / "mkd6fs-v1373.log")
    execute([bindir / "logstore", "-n", "4", "-d", disk, "--init"])
    execute([bindir / "d6fsck", "-n", "4", "-d", disk])
    print("V1373_D6FS_CLEAN_PASS", flush=True)


if __name__ == "__main__":
    if len(sys.argv) != 10:
        raise SystemExit("usage: build_root_v1373.py DAIMOS TESTKIT WORK NATIVE C_SOURCE PACKED_GOLD NESTED_SOURCE NESTED_PACKED_GOLD NESTED_DXR")
    build(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve(),
          Path(sys.argv[3]).resolve(), Path(sys.argv[4]).resolve(),
          tuple(Path(p).resolve() for p in sys.argv[5:]))
