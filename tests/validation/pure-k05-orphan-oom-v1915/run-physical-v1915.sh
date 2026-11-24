#!/bin/sh
# Original PDP-6 test-only USER BRK capacity OOM under foreign FULL claim.
set -eu
: "${V1915_BUILD:?original source-built 48K v1915 guest required}"
: "${V1915_PROBE:?original fixed PURE physical probe required}"
: "${DAIMOS_REPO:?original DAIMOS source required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1915_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-orphan-oom-v1915.XXXXXX")}
mkdir -p "$work"
source_work=$(CDPATH= cd -- "$V1915_BUILD/.." && pwd)
test -s "$source_work/tsfs-root-v1638.manifest"
grep -F "F /SYSTEM/COMP $source_work/user/comp-v1638.dxr " \
  "$source_work/tsfs-root-v1638.manifest" >/dev/null
for unit in 0 1 2; do
  cmp "$source_work/tsfs-v1638${unit}.dta" \
      "$V1915_BUILD/media/dtc${unit}.tap"
done
"$V1915_BUILD/tsfscheck-v1461" \
  "$source_work/tsfs-v16380.dta" \
  "$source_work/tsfs-v16381.dta" \
  "$source_work/tsfs-v16382.dta"
python3 "$here/prepare-physical-v1915.py" "$kit" "$V1915_BUILD" \
  "$V1915_PROBE" "$work" "$PDP10_PREFIX"
port=$((45000+($$%1100)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1915_BUILD" && TERM=dumb timeout -k 3s "${V1915_TIMEOUT:-900}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/physical.log" >"$work/physical.clean"
if [ "$rc" -ne 0 ]; then
  tail -85 "$work/physical.clean" >&2
  echo "FAIL v1915 original PDP-6 simulator rc=$rc: $work" >&2
  exit 1
fi
python3 "$here/verify-physical-v1915.py" "$kit" "$V1915_BUILD" "$work"
echo "v1915 original requester-OOM/held orphan physical evidence: $work"
