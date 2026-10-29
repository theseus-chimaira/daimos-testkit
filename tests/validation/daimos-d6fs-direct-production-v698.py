#!/usr/bin/env python3
"""Verify the production eight-site physical D6FS binding contract."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]); fs = (root/'system/kernel/storage/fs_backing.s').read_text()
minit = (root/'system/kernel/modules/module_minit.c').read_text()
mk = (root/'system/boot/pdp6/Makefile').read_text()
names = ['fs_backing_direct_read_jump','fs_backing_direct_write_jump',
         'fs_backing_direct_drm_read_jump','fs_backing_direct_drm_write_jump',
         'fs_backing_direct_root_read_call','fs_backing_direct_root_write_call',
         'fs_backing_direct_root_drm_read_call','fs_backing_direct_root_drm_write_call']
for name in names:
    assert len(re.findall(r'^'+name+r':',fs,re.M))==1,name
    assert '-X '+name in mk,name
for idx in range(7,15):
    assert re.search(r'minit_export\(name, base, '+str(idx)+r'U\)',minit),idx
for name in names[4:]:
    assert re.search(r'^'+name+r':\s*\n\s*pushj\s+17,kret_neg1',fs,re.M),name
assert re.search(r'^fs_backing_direct_read_jump:\s*\n\s*jumpe\s+7,kret_neg1',fs,re.M)
assert re.search(r'^fs_backing_direct_drm_read_jump:\s*\n\s*jumpe\s+7,kret_neg1',fs,re.M)
assert 'module_service_get(MODULE_SERVICE_DSK_READ_SECTOR)' in minit
assert 'module_service_get(MODULE_SERVICE_DRM_READ_BLOCK)' in minit
print('v698: eight D6FS physical backend patch sites and MRES exports PASS')
