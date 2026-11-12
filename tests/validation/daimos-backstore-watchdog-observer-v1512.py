#!/usr/bin/env python3
"""Suppress selected DR_DONE publication to exercise the real PI6 watchdog.

Inject *after* the disposable v1511 source-linked Type-167/236 observer.
The first two post-fault reads of the actual failed BACKSTORE owner are
transferred on hardware, but their selected PI2 drum DONE acknowledgments
are deliberately dropped. The descriptor remains owned and active until
production drm236_watchdog_tick_v1079 fails it after its 300-tick budget.

All modifications are confined to an isolated full-guest kernel copy.
No scheduler, MM rollback, backing record or production code is edited.
"""

from pathlib import Path
import sys


def once(source, old, new, name):
    if source.count(old) != 1:
        raise ValueError("v1512 source anchor drift: " + name)
    return source.replace(old, new, 1)


def inject(root):
    bridge = root / "fs/fs_mres.s"
    driver = root / "drivers/drm236_io.s"
    backing = root / "storage/backstore_entry_v484.s"

    source = bridge.read_text()
    source = once(source,
        "        move    4,daimos_v1511_device_errors\n"
        "        caige   4,2\n",
        "        ; v1512: stop selecting after two lost drum completions.\n"
        "        move    4,daimos_v1512_lost_pi2\n"
        "        caige   4,2\n", "selection bound")
    bridge.write_text(("        .globl daimos_v1512_lost_pi2\n") + source)

    source = driver.read_text()
    if source.count("        camn    1,daimos_v1511_target_descriptor\n") != 1:
        raise ValueError("v1512 source anchor drift: descriptor retirement")
    source = once(source,
        "        setzm   daimos_v1511_target_descriptor\n"
        "        aos     daimos_v1511_device_errors\n"
        "        jrst    drm236_pi_error\n"
        "daimos_v1511_pi_normal:\n",
        "        ; v1512: hardware DR_DONE arrived, but its completion is\n"
        "        ; not published to the still-owned private descriptor.\n"
        "        ; Deselect the real drum to avoid an interrupt storm.\n"
        "        ; Leave target_descriptor valid until real PI6 timeout.\n"
        "        aos     daimos_v1512_lost_pi2\n"
        "        cono    0400,DRM_DR_DESELECT\n"
        "        jrst    pdp10_pi_dispatch_done\n"
        "daimos_v1511_pi_normal:\n", "lost DR_DONE completion")

    if source.count("drm236_watchdog_tick_v1079:\n"
                    "        skipn   drm236_active_request\n") != 1:
        raise ValueError("v1512 source anchor drift: production timeout entry")
    # Only the real countdown-zero path is counted. This is deliberately
    # not a synthetic status return or a changed watchdog deadline.
    source = once(source,
        "        cono    0010,0\n"
        "        cono    0400,DRM_DR_CLEAR_DESELECT\n"
        "        seto    2,\n"
        "        pushj   017,drm236_finish_active_v1079\n"
        "drm236_watchdog_return_v1079:\n",
        "        cono    0010,0\n"
        "        cono    0400,DRM_DR_CLEAR_DESELECT\n"
        "        hrrz    1,drm236_active_request\n"
        "        came    1,daimos_v1511_target_descriptor\n"
        "        jrst    daimos_v1512_timeout_other\n"
        "        aos     daimos_v1512_watchdog_errors\n"
        "daimos_v1512_timeout_other:\n"
        "        seto    2,\n"
        "        pushj   017,drm236_finish_active_v1079\n"
        "drm236_watchdog_return_v1079:\n", "real PI6 timeout witness")
    driver.write_text(("        .globl daimos_v1512_lost_pi2\n"
                       "        .globl daimos_v1512_watchdog_errors\n") + source)

    source = backing.read_text()
    source += "\n; v1512 disposable lost-PI2 and real-PI6-timeout witnesses.\n        .bss\n"
    for name in ("lost_pi2", "watchdog_errors"):
        label = "daimos_v1512_" + name
        if label + ":" in source:
            raise ValueError("v1512 duplicate instrument " + label)
        source += "        .globl %s\n%s: .block 1\n" % (label, label)
    backing.write_text(source)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: v1512.py DISPOSABLE-KERNEL-ROOT")
    inject(Path(sys.argv[1]))
