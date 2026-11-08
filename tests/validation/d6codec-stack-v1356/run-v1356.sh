#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-stack-v1356"
mkdir -p "$work"

# Use the same complete original DXR corpus as the v055 ABI fixture.
python3 - "$testkit/tests/validation/d6codec-native-v051/test_darc_v051.s" \
  "$work/test_v1356.s" <<'PYGEN'
import sys
source = open(sys.argv[1]).read()
source = source.replace('d6v051_encode_literals',
                        'd6codec_kcore_encode_v055')
source = source.replace('d6v051_decode',
                        'd6codec_kcore_decode_v055')
for symbol in ('d6codec_kcore_encode_v055', 'd6codec_kcore_decode_v055'):
    needle = ' pushj 17,' + symbol + '\n'
    assert source.count(needle) == 1
    before = ''.join(' movei %d,%d\n' % (i, i + 100)
                     for i in range(10, 17))
    after = ''.join(' caie %d,%d\n jrst fail\n' % (i, i + 100)
                    for i in range(10, 17))
    source = source.replace(needle, before + needle + after)
open(sys.argv[2], 'w').write(source)
PYGEN

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
  --start 1000 --timeout 30 --workdir "$work/run" \
  --name d6codec-stack-v1356 --expect __test_exit=0 \
  --expect __v051_first_changed=016 \
  "$testkit/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
  "$work/test_v1356.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_kcore_abi_v055.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_encode_v053.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_decode_v053.s"
