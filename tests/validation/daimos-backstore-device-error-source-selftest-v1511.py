#!/usr/bin/env python3
"""Check that v1511 only instruments the chosen real hardware error path."""

from pathlib import Path
import os
import runpy
import shutil
import tempfile
import sys


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: v1511-selftest.py DAIMOS-KERNEL-ROOT")
    production = Path(sys.argv[1])
    mod = runpy.run_path(str(Path(__file__).resolve().parent /
                              "daimos-backstore-device-error-observer-v1511.py"))
    rels = ("fs/fs_mres.s", "drivers/drm236_io.s",
            "storage/backstore_entry_v484.s")
    with tempfile.TemporaryDirectory(prefix="daimos-device-v1511-",
                                     dir=os.environ.get("TMPDIR", os.path.expanduser("~/tmp"))) as temp:
        root = Path(temp)
        for rel in rels:
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(production / rel, root / rel)
        original = {rel: (root / rel).read_text() for rel in rels}
        mod["inject"](root)
        bridge = (root / rels[0]).read_text()
        driver = (root / rels[1]).read_text()
        backing = (root / rels[2]).read_text()
        for anchor in (
                "came    4,daimos_v1494_slot",
                "setzm   daimos_v1511_this_read",
                "caige   4,2",
                "jrst    backing_region_io"):
            if anchor not in bridge:
                raise AssertionError("v1511 lost selective media gateway: " + anchor)
        for anchor in (
                "drm236_runtime_retry:",
                "drm236_pi_handler:",
                "came    2,daimos_v1511_target_descriptor",
                "aos     daimos_v1511_device_errors",
                "jrst    drm236_pi_error",
                "drm236_finish_active_v1079:",
                "camn    1,daimos_v1511_target_descriptor",
                "aos     mfsdev_storage_errors+5"):
            if anchor not in driver:
                raise AssertionError("v1511 bypassed production DRM: " + anchor)
        if backing.count("daimos_v1511_device_errors: .block 1") != 1:
            raise AssertionError("v1511 source-linked diagnostic word missing")
        if backing.count("daimos_v1511_target_descriptor: .block 1") != 1:
            raise AssertionError("v1511 descriptor identity witness missing")
        # The error branch is the original DRM PI2 error routine, not a
        # fake success/error return in the production swap transaction.
        if "proc_swap_in" in driver or "proc_swap_in" in bridge:
            raise AssertionError("v1511 inserted swap policy into driver")
        for title, rel, old in (
                ("backing-anchor", rels[0], "backstore_read:\n"),
                ("wrong-backing-DEVICE", rels[0],
                 "        pushj   17,drm236_read_block\n"),
                ("descriptor-anchor", rels[1], "drm236_runtime_retry:\n"),
                ("pi2-anchor", rels[1], "        trnn    1,DRM_DR_DONE\n"),
                ("error-anchor", rels[1], "        movem   2,2(1)\n"),
        ):
            for path in rels:
                (root / path).write_text(original[path])
            source = (root / rel).read_text().replace(old, "v1511_broken:\n", 1)
            (root / rel).write_text(source)
            try:
                mod["inject"](root)
            except ValueError:
                continue
            raise AssertionError("v1511 accepted damaged source: " + title)
    print("PASS v1511: targeted PI2 error, real DRM descriptor retirement")
    print("PASS v1511: five source drift and wrong-DEVICE mutations rejected")


if __name__ == "__main__":
    main()
