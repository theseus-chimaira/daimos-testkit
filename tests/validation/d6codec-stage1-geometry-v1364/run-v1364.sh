#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-stage1-geometry-v1364"
mkdir -p "$work"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --exec-mode go --start 1000 --timeout 30 \
  --workdir "$work/native" --name d6codec-geometry-v1364 \
  --expect __test_exit=0 \
  "$root/tests/validation/daimos-test-crt0-v1.s" \
  "$root/tests/validation/d6codec-stage1-geometry-v1364/test_geometry_v1364.s" \
  "$DAIMOS_REPO/system/stand/pdp6/common/stage1-geometry-v1364.inc"
for core in 0100000 01000000; do
  dest="$work/core_$core"
  python3 "$root/tests/validation/d6codec-stage1-geometry-v1364/generate-v1364.py" \
    "$DAIMOS_REPO" "$root" "$dest" "$core" 0400
  for kind in dsk drm dtc mtc ptr; do
    "$PDP10_PREFIX/bin/das" -F -K \
      -O "$dest/stage1-$kind-v1363.dxr" \
      "$dest/stage1-$kind-v1363.s"
    "$PDP10_PREFIX/bin/das" -F -K \
      -L "$dest/stage1-$kind-v1364.labels" \
      -O "$dest/stage1-$kind-v1364.dxr" \
      "$dest/stage1-$kind-v1364.s"
    fixture="$dest/guard-$kind-v1364.s"
    python3 "$root/tests/validation/d6codec-stage1-geometry-v1364/generate-guard-v1364.py" \
      "$dest/stage1-$kind-v1364.s" "$kind" "$core" 0400 "$fixture"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
      --exec-mode go --start 1000 --timeout 30 \
      --workdir "$dest/native-$kind" --name "d6codec-geom-$kind-$core-v1364" \
      --expect __test_exit=0 \
      "$root/tests/validation/daimos-test-crt0-v1.s" \
      "$fixture" \
      "$DAIMOS_REPO/system/stand/pdp6/common/stage1-geometry-v1364.inc"
  done
done
python3 "$root/tests/validation/d6codec-stage1-geometry-v1364/inspect-v1364.py" "$work"
# Exercise configuration propagation beyond the two normal profiles.
# 64K of core and 1K of reserve is a legal parameter combination.
core=0200000
reserve=02000
dest="$work/core_${core}_stack_${reserve}"
python3 "$root/tests/validation/d6codec-stage1-geometry-v1364/generate-v1364.py" \
  "$DAIMOS_REPO" "$root" "$dest" "$core" "$reserve"
for kind in dtc ptr; do
  "$PDP10_PREFIX/bin/das" -F -K \
    -O "$dest/stage1-$kind-v1364.dxr" \
    "$dest/stage1-$kind-v1364.s"
  fixture="$dest/guard-$kind-v1364.s"
  python3 "$root/tests/validation/d6codec-stage1-geometry-v1364/generate-guard-v1364.py" \
    "$dest/stage1-$kind-v1364.s" "$kind" "$core" "$reserve" "$fixture"
  "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$dest/native-$kind" --name "d6codec-geom-$kind-$core-v1364" \
    --expect __test_exit=0 \
    "$root/tests/validation/daimos-test-crt0-v1.s" \
    "$fixture" \
    "$DAIMOS_REPO/system/stand/pdp6/common/stage1-geometry-v1364.inc"
done
echo 'PASS v1364: native geometry, twelve staged builds and twelve native header guards'
