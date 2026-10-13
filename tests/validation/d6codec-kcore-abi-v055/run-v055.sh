#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR/d6codec-kcore-abi-v055"
fixture="$DAIMOS_REPO/../daimos-testkit/tests/validation/d6codec-native-v051/test_darc_v051.s"
# Reuse the independently recorded v051 golden darc corpus, unchanged.
python3 - "$fixture" "$TMPDIR/d6codec-kcore-abi-v055/test_v055.s" <<'PYGEN'
import sys
src = open(sys.argv[1]).read()
src = src.replace('d6v051_encode_literals', 'd6codec_kcore_encode_v055')
src = src.replace('d6v051_decode', 'd6codec_kcore_decode_v055')
for name in ('d6codec_kcore_encode_v055', 'd6codec_kcore_decode_v055'):
    needle = f' pushj 17,{name}\n'
    assert src.count(needle) == 1
    before = ''.join(f' movei {i},{i+100}\n' for i in range(10, 17))
    after = ''.join(f' caie {i},{i+100}\n jrst fail\n' for i in range(10, 17))
    src = src.replace(needle, before + needle + after)
open(sys.argv[2], 'w').write(src)
PYGEN
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
  --start 1000 --timeout 30 --workdir "$TMPDIR/d6codec-kcore-abi-v055/run" \
  --name d6codec-kcore-abi-v055 --expect __test_exit=0 \
  "$DAIMOS_REPO/../daimos-testkit/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
  "$TMPDIR/d6codec-kcore-abi-v055/test_v055.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_kcore_abi_v055.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_encode_v053.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_decode_v053.s"
