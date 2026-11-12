#!/usr/bin/env python3
"""Fail-closed source contract for disposable lost-PI2 timeout injection."""

from pathlib import Path
import os
import runpy
import shutil
import sys
import tempfile


HERE = Path(__file__).resolve().parent
FILES = ("fs/fs_mres.s", "drivers/drm236_io.s",
         "storage/backstore_entry_v484.s")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: v1512-selftest.py DAIMOS-KERNEL-ROOT")
    base = Path(sys.argv[1])
    v1511 = runpy.run_path(str(HERE / "daimos-backstore-device-error-observer-v1511.py"))
    v1512 = runpy.run_path(str(HERE / "daimos-backstore-watchdog-observer-v1512.py"))
    with tempfile.TemporaryDirectory(prefix="daimos-watchdog-v1512-",
                                     dir=os.environ.get("TMPDIR", os.path.expanduser("~/tmp"))) as tmp:
        root = Path(tmp)
        for rel in FILES:
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(base / rel, root / rel)
        v1511["inject"](root)
        before = {rel: (root / rel).read_text() for rel in FILES}
        v1512["inject"](root)
        bridge = (root / FILES[0]).read_text()
        driver = (root / FILES[1]).read_text()
        backing = (root / FILES[2]).read_text()
        for anchor in (
                "move    4,daimos_v1512_lost_pi2",
                "came    4,daimos_v1494_slot",
                "jrst    backing_region_io"):
            if anchor not in bridge:
                raise AssertionError("v1512 unbounded/incorrect owner: " + anchor)
        for anchor in (
                "aos     daimos_v1512_lost_pi2",
                "cono    0400,DRM_DR_DESELECT",
                "jrst    pdp10_pi_dispatch_done",
                "aos     daimos_v1512_watchdog_errors",
                "came    1,daimos_v1511_target_descriptor",
                "pushj   017,drm236_finish_active_v1079",
                "camn    1,daimos_v1511_target_descriptor",
                "drm236_watchdog_tick_v1079:",
                "        movsi   1,-1"):
            if anchor not in driver:
                raise AssertionError("v1512 lost genuine PI6 watchdog: " + anchor)
        for name in ("lost_pi2", "watchdog_errors"):
            if backing.count("daimos_v1512_%s: .block 1" % name) != 1:
                raise AssertionError("v1512 missing exact witness: " + name)
        if "aos     daimos_v1511_device_errors" in driver:
            raise AssertionError("v1512 must not claim a lost PI2 was a PI2 error")
        if "0454" not in driver or "drm236_pi_error:" not in driver:
            raise AssertionError("v1512 changed original hardware timeout/error policy")
        for label, rel, old in (
                ("owner-select", FILES[0], "move    4,daimos_v1511_device_errors"),
                ("DR-completion", FILES[1], "aos     daimos_v1511_device_errors"),
                ("PI6-timeout", FILES[1], "drm236_watchdog_return_v1079:"),
                ("descriptor-retire", FILES[1], "camn    1,daimos_v1511_target_descriptor"),
        ):
            for path in FILES:
                (root / path).write_text(before[path])
            (root / rel).write_text(before[rel].replace(old, "BROKEN_v1512", 1))
            try:
                v1512["inject"](root)
            except ValueError:
                continue
            raise AssertionError("v1512 accepted malformed source: " + label)
    print("PASS v1512: real PI6 300-tick watchdog and descriptor wakeup intact")
    print("PASS v1512: four malformed source variants rejected")


if __name__ == "__main__":
    main()
