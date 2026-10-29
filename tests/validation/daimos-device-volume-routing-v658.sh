#!/bin/sh
# Source-level ABI/routing regression for the first DEVICE/VOLUME split.
set -eu
: "${DAIMOS_REPO:?}"
fs="$DAIMOS_REPO/system/kernel/fs/fs_mres.s"
boot="$DAIMOS_REPO/system/kernel/storage/blockset_boot.c"
aux="$DAIMOS_REPO/system/kernel/storage/auxstore_boot.c"
python3 - "$fs" "$boot" "$aux" <<'PY'
import re,sys
fs,boot,aux=[open(p).read() for p in sys.argv[1:]]
def require(ok,what):
    if not ok: raise SystemExit('v658: '+what)
require(re.search(r'blockset_direct_configure:\s*\nvolume_tail_configure:',fs),
        'legacy and volume setup must retain identical entry ABI')
require(re.search(r'device_range_configure:\s*\n\s*move\s+4,3\s*\n\s*setz\s+3,\s*\n\s*jrst\s+blockset_direct_configure',fs),
        'direct DEVICE setup must bypass volume mapping')
require('jrst    device_range_translate' in fs and
        'jrst    device_block_transfer' in fs,
        'direct and mapped paths must join shared physical I/O')
require('device_range_configure(selector, auxstore_backstore_start,' in aux,
        'AUXSTORE BACKSTORE must use direct DEVICE region')
require('device_range_configure(direct_selector,' in boot and
        boot.count('volume_tail_configure(')==2,
        'singleton and multi-member root routing changed')
print('daimos-device-volume-routing-v658: PASS')
PY
