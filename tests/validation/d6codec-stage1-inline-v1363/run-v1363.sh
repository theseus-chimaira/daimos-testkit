#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-stage1-inline-v1363"
mkdir -p "$work"
python3 "$testkit/tests/validation/d6codec-stage1-inline-v1363/generate-v1363.py" \
  "$DAIMOS_REPO" "$work"
for kind in dsk drm dtc mtc ptr; do
  echo "ASSEMBLE staged direct-linked Stage-1 $kind"
  "$PDP10_PREFIX/bin/das" -F -K \
    -L "$work/stage1-$kind-v1363.labels" \
    -O "$work/stage1-$kind-v1363.dxr" "$work/stage1-$kind-v1363.s"
  "$PDP10_PREFIX/bin/das" -F -K \
    -L "$work/stage1-$kind-original.labels" \
    -O "$work/stage1-$kind-original.dxr" \
    "$DAIMOS_REPO/system/stand/pdp6/$kind/stage1.s"
  "$PDP10_PREFIX/bin/dxrconvert" --pdp6-readin -b 060 \
    "$work/stage1-$kind-v1363.dxr" "$work/stage1-$kind-v1363.pt"
done
python3 "$testkit/tests/validation/d6codec-stage1-inline-v1363/inspect-v1363.py" "$work"
for kind in dsk drm dtc mtc ptr; do
  for mode in good bad; do
    fixture="$work/handoff-$kind-$mode-v1363.s"
    python3 "$testkit/tests/validation/d6codec-stage1-inline-v1363/generate-handoff-v1363.py" \
      "$work/stage1-$kind-v1363.s" "$kind" "$mode" "$fixture"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
      --exec-mode go --start 060 --timeout 25 \
      --workdir "$work/run-$kind-$mode" \
      --name "d6codec-handoff-$kind-$mode-v1363" --expect __test_exit=0 \
      "$testkit/tests/validation/daimos-test-crt0-v1.s" \
      "$fixture" "$DAIMOS_REPO/system/kernel/core/d6codec_decode_v053.s"
  done
done
echo 'PASS v1363: all five linked handoffs, success/failure on native PDP-6'
