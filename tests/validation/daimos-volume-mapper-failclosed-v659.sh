#!/bin/sh
# Guard the PDP-6 backing bridge against implicit fallback to device zero
# when the selected multi-member VOLUME mapper has been unloaded.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" <<'PY'
import re, sys
s=open(sys.argv[1]).read()
def check(predicate, message):
    if not predicate:
        raise SystemExit('v659: '+message)
loop=s.split('blockset_direct_tail_loop:',1)[1].split('; Direct DEVICE path:',1)[0]
check(re.search(r'skipn\s+volume_data_blocks\s*\n\s*jrst\s+device_range_translate',loop),
      'a direct DEVICE range must bypass the mapper')
check(re.search(r'blockset_runtime_service_call:\s*\n\s*pushj\s+17,kret_neg1',loop),
      'missing multi-member mapper must fail closed through direct default')
check(re.search(r'blockset_direct_tail_error:\s*\n\s*seto\s+1,\s*\n\s*jrst\s+blockset_direct_tail_done',loop),
      'failed mapper must return negative without device I/O')
check('pushj   17,kret_neg1' in loop and 'jrst    device_block_transfer' in loop,
      'installed mapper must use the shared device transfer')
print('daimos-volume-mapper-failclosed-v659: PASS')
PY
