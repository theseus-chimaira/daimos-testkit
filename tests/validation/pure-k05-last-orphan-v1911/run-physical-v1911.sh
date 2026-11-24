#!/bin/sh
# Reuse the accepted original v1910 source-built 48K guest unchanged.
set -eu
: "${V1911_BUILD:?source-built original v1910 48K guest required}"
: "${V1911_PROBE:?source-linked original PURE probe required}"
: "${DAIMOS_REPO:?original DAIMOS source required for BSS-layout proof}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1911_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-last-orphan-v1911.XXXXXX")}
mkdir -p "$work"
source_work=$(CDPATH= cd -- "$V1911_BUILD/.." && pwd)
test -s "$source_work/tsfs-root-v1638.manifest"
grep -F "F /SYSTEM/COMP $source_work/user/comp-v1638.dxr " \
  "$source_work/tsfs-root-v1638.manifest" >/dev/null
for unit in 0 1 2; do
  cmp "$source_work/tsfs-v1638${unit}.dta" \
      "$V1911_BUILD/media/dtc${unit}.tap"
done
"$V1911_BUILD/tsfscheck-v1461" \
  "$source_work/tsfs-v16380.dta" \
  "$source_work/tsfs-v16381.dta" \
  "$source_work/tsfs-v16382.dta"
python3 "$here/prepare-physical-v1911.py" "$kit" "$V1911_BUILD" \
  "$V1911_PROBE" "$work" "$PDP10_PREFIX"
port=$((41000+($$%1700)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1911_BUILD" && TERM=dumb timeout -k 3s "${V1911_TIMEOUT:-750}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  >"$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' < "$work/physical.log" > "$work/physical.clean"
if [ "$rc" -ne 0 ]; then
  tail -75 "$work/physical.clean" >&2
  echo "FAIL v1911 original last-orphan physical simulator rc=$rc: $work" >&2
  exit 1
fi
python3 "$here/verify-physical-v1911.py" "$kit" "$V1911_BUILD" "$work"
echo "v1911 last-orphan original physical evidence: $work"
