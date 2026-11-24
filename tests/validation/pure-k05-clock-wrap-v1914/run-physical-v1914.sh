#!/bin/sh
# Original PDP-6 17-bit timer-wrap experiment with solely clock/epoch leap.
set -eu
: "${V1914_BUILD:?original source-built 48K guest required}"
: "${V1914_PROBE:?original PURE physical probe required}"
: "${DAIMOS_REPO:?original DAIMOS source tree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1914_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-clock-wrap-v1914.XXXXXX")}
mkdir -p "$work"
source_work=$(CDPATH= cd -- "$V1914_BUILD/.." && pwd)
test -s "$source_work/tsfs-root-v1638.manifest"
grep -F "F /SYSTEM/COMP $source_work/user/comp-v1638.dxr " \
  "$source_work/tsfs-root-v1638.manifest" >/dev/null
for unit in 0 1 2; do
  cmp "$source_work/tsfs-v1638${unit}.dta" \
      "$V1914_BUILD/media/dtc${unit}.tap"
done
"$V1914_BUILD/tsfscheck-v1461" \
  "$source_work/tsfs-v16380.dta" \
  "$source_work/tsfs-v16381.dta" \
  "$source_work/tsfs-v16382.dta"
python3 "$here/prepare-physical-v1914.py" "$kit" "$V1914_BUILD" \
  "$V1914_PROBE" "$work" "$PDP10_PREFIX"
port=$((44000+($$%1000)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1914_BUILD" && TERM=dumb timeout -k 3s "${V1914_TIMEOUT:-900}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' < "$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
  tail -85 "$work/physical.clean" >&2
  echo "FAIL v1914 physical simulator rc=$rc: $work" >&2
  exit 1
fi
python3 "$here/verify-physical-v1914.py" "$kit" "$V1914_BUILD" "$work"
echo "v1914 original 17-bit clock-wrap evidence: $work"
