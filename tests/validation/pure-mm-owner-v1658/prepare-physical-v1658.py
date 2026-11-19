#!/usr/bin/env python3
"""Recenter original v1643 secondary-read physical test on v1658 map.

The source-linked native v1658 changes move the MRES code. No scheduler,
trace, media, device, or owner oracle is replaced. Required machine words
are independently verified in the exact linked DXR before replay.
"""

from pathlib import Path
import re
import subprocess
import sys


def symbols(path):
    return dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-zA-Z_][a-zA-Z0-9_]*)\s+([0-7]+)\s*$",
        path.read_text(encoding="ascii")))


def main(original, build, outdir, dxrcheck):
    original, build, outdir = map(Path, (original, build, outdir))
    outdir.mkdir(parents=True, exist_ok=True)
    mres = symbols(build / "pure-mres-v1612.map")
    core = symbols(build / "kcore.map")
    expect = {
        "proc_pure_ram_restore_v1391": 0o2216,
        "exec_image_full_bounded_v1391": 0o3243,
        "proc_pure_mres_service_v1612": 0o363,
    }
    for name, value in expect.items():
        if mres.get(name) != value:
            raise ValueError("unrecognized v1658 MRES %s" % name)
    if core.get("kcore_root_fs_io_failure_v1538") != 0o3761:
        raise ValueError("unrecognized source-built fixed KCORE")
    if (build / "boot.ini").read_text(encoding="ascii").count(
            "set cpu 48k\n") != 1:
        raise ValueError("not the original 48K physical profile")
    dump = subprocess.check_output([str(dxrcheck), "-d",
                                    str(build / "pure-mres-v1612.dxr")],
                                   text=True)
    for offset, word in ((0o3243, "200000000004"),
                         (0o447, "260740002216"),
                         (0o450, "326040000466"),
                         (0o2342, "561400777774")):
        if "IMAGE  %06o %s" % (offset, word) not in dump:
            raise ValueError("linked MRES instruction mismatch at %06o" %
                             offset)
    replacements = (
        ("0o3224", "0o3243"),
        ("0o2207", "0o2216"),
        ("0o0432", "0o0447"),
        ("0o0433", "0o0450"),
        ("0o2333", "0o2342"),
        ("0o433", "0o450"),
        ("260740002207", "260740002216"),
        ("326040000451", "326040000466"),
    )
    for name, target in (("replay-v1643.sh", "replay-derived-v1658.sh"),
                         ("audit-v1643.py", "audit-v1643.py"),
                         ("run-audit-v1643.sh", "run-audit-derived-v1658.sh")):
        data = (original / name).read_text(encoding="ascii")
        for old, new in replacements:
            count = data.count(old)
            if count:
                if new in data:
                    raise ValueError("mixed original/new source anchors")
                data = data.replace(old, new)
        if name == "audit-v1643.py":
            root = "Path(__file__).resolve().parent.parent /"
            if data.count(root) != 1:
                raise ValueError("original physical parser import drift")
            data = data.replace(root,
                "Path(__import__('os').environ['P1E_V1658_ORIGINAL_DIR']).parent /", 1)
        if name.endswith(".sh"):
            root = 'here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)'
            if data.count(root) != 1:
                raise ValueError("original physical runner path drift")
            if name.startswith("replay"):
                data = data.replace(root, 'here="$P1E_V1658_ORIGINAL_DIR"', 1)
                work = "pure-secondary-read-v1643.XXXXXX"
                if data.count(work) != 1:
                    raise ValueError("original physical evidence path drift")
                data = data.replace(work, "pure-secondary-read-v1658.XXXXXX", 1)
            else:
                data = data.replace(root, 'here="$P1E_V1658_GENERATED_DIR"', 1)
        (outdir / target).write_text(data, encoding="ascii")
    print("v1658: physical FULL offsets 03243/0447/0450/02342 verified")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        raise SystemExit("usage: prepare-physical-v1658.py original-dir build out dxrcheck")
    main(*sys.argv[1:])
