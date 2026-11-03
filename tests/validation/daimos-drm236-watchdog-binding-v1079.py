#!/usr/bin/env python3
"""Source contract: the resident clock reaches the DRM timeout service."""
import os
from pathlib import Path

root = Path(os.environ["DAIMOS_REPO"])
clock = (root / "system/kernel/storage/storage_router.s").read_text()
drm = (root / "system/kernel/drivers/drm236_io.s").read_text()
minit = (root / "system/kernel/modules/module_minit.c").read_text()
boot = (root / "system/boot/pdp6/Makefile").read_text()

# The DSK call must return before the DRM tail call. Both default to a
# harmless no-op until the corresponding MRES is installed by MINIT.
assert "storage_clock_dsk_jump:\n        pushj 017,storage_clock_noop\n" in clock
assert "storage_clock_drm_jump:\n        jrst storage_clock_noop\n" in clock
assert clock.index("storage_clock_dsk_jump:") < clock.index(
    "storage_clock_drm_jump:")
assert '#define DRM_X_WATCHDOG            3U' in minit
assert 'storage_patch_jump(&storage_clock_drm_jump,' in minit
assert 'minit_export(name, base, DRM_X_WATCHDOG)' in minit
assert "-X drm236_watchdog_tick_v1079" in boot

# Countdown is packed into the existing active-request word, not a
# permanent second request table. Completion must mask off the LH.
assert 'hrli    1,DRM_WATCHDOG_TICKS_V1079' in drm
assert 'hrrz    1,drm236_active_request' in drm
assert 'drm236_watchdog_tick_v1079:' in drm
assert 'pushj   017,drm236_finish_active_v1079' in drm
assert 'drm236_watchdog_return_v1079:' in drm
assert '.bss' not in drm

print("v1079: clock/DSK/DRM MINIT and packed 300-tick watchdog contract PASS")
