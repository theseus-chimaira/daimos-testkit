#!/usr/bin/env python3
"""Derive strict v1643 physical FULL replay/audit for v1654 GCC layout.

The original v1643 test pins exact original code words at 03224; the
v1654 transaction places bounded loader at 03233 without changing
the original service entry or source-linked loader return PC.
Only these verified constants and script locations are adapted.
The original real DTC3 detach, rollback and forged-trace oracles remain.
"""

from pathlib import Path
import re
import sys


OLD_LOADER = "0o3224"
NEW_LOADER = "0o3233"


def symbols(data):
    return dict((name, int(value, 8))
                for name, value in re.findall(
                    r"(?m)^([a-zA-Z_][a-zA-Z0-9_]*)\s+([0-7]+)\s*$",
                    data))


def main(original, build, output):
    original, build, output = map(Path, (original, build, output))
    output.mkdir(parents=True, exist_ok=True)
    refs = symbols((build / "pure-mres-v1612.map").read_text(
        encoding="ascii"))
    assert refs["proc_pure_ram_restore_v1391"] == 0o2207
    assert refs["exec_image_full_bounded_v1391"] == 0o3233
    assert refs["proc_pure_mres_service_v1612"] == 0o346
    krefs = symbols((build / "kcore.map").read_text(encoding="ascii"))
    assert krefs["kcore_root_fs_io_failure_v1538"] == 0o3761
    assert (build / "boot.ini").read_text(encoding="ascii").count(
        "set cpu 48k\n") == 1

    def apply(name, output_name, relocated):
        path = original / name
        script = path.read_text(encoding="ascii")
        if relocated:
            assert script.count(OLD_LOADER) >= 2
            assert NEW_LOADER not in script
            script = script.replace(OLD_LOADER, NEW_LOADER)
        else:
            assert OLD_LOADER not in script
        if name == "audit-v1643.py":
            # The original auditor imports the shared v1638 MM parser
            # relative to its testkit source location. The derived auditor
            # lives in a disposable evidence directory instead, and must
            # still import exactly the ORIGINAL testkit parser.
            old_root = "Path(__file__).resolve().parent.parent /"
            assert script.count(old_root) == 1
            script = script.replace(old_root,
                "Path(__import__('os').environ['P1E_V1654_ORIGINAL_DIR']).parent /",
                1)
        if name.endswith(".sh"):
            old_here = 'here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)'
            assert script.count(old_here) == 1
            new_here = ('here="$P1E_V1654_GENERATED_DIR"' if
                        name.startswith("run-audit") else
                        'here="$P1E_V1654_ORIGINAL_DIR"')
            script = script.replace(old_here, new_here, 1)
            if name.startswith("replay"):
                old_dir = 'pure-secondary-read-v1643.XXXXXX'
                assert script.count(old_dir) == 1
                script = script.replace(
                    old_dir, 'pure-secondary-read-v1654.XXXXXX', 1)
        (output / output_name).write_text(script, encoding="ascii")

    apply("replay-v1643.sh", "replay-derived-v1654.sh", True)
    apply("audit-v1643.py", "audit-v1643.py", True)
    apply("run-audit-v1643.sh", "run-audit-derived-v1654.sh", False)
    print("v1654: strict original v1643 FULL physical replay recentered "
          "03224 -> 03233")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: prepare-physical-v1654.py v1643-dir build outdir")
    main(*sys.argv[1:])
