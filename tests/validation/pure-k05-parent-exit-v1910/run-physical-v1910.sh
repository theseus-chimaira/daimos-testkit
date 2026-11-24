#!/bin/sh
# One real parent EXIT while the failed-FULL child is unrecoverably foreign.
set -eu
: "${V1910_BUILD:?source-built original 48K guest required}"
: "${V1910_PROBE:?source-linked installed PURE base probe required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1910_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-parent-exit-v1910.XXXXXX")}
mkdir -p "$work"
# The original v1638 compressed /SYSTEM/COMP post-build hook must
# have completed. An interrupted source build can leave valid KCORE
# binaries but an INCOMPLETE TSFS guest. Never silently copy plain
# boot tapes into this fixture: the real guest then fails with !3.
source_work=$(CDPATH= cd -- "$V1910_BUILD/.." && pwd)
test -s "$source_work/tsfs-root-v1638.manifest"
grep -F "F /SYSTEM/COMP $source_work/user/comp-v1638.dxr " \
  "$source_work/tsfs-root-v1638.manifest" >/dev/null
test -s "$source_work/user/comp-v1638.dxr"
for unit in 0 1 2; do
  original="$source_work/tsfs-v1638${unit}.dta"
  bootcopy="$V1910_BUILD/media/dtc${unit}.tap"
  test -s "$original"
  test -s "$bootcopy"
  cmp "$original" "$bootcopy"
done
"$V1910_BUILD/tsfscheck-v1461" \
  "$source_work/tsfs-v16380.dta" \
  "$source_work/tsfs-v16381.dta" \
  "$source_work/tsfs-v16382.dta"
python3 "$here/prepare-physical-v1910.py" "$kit" "$V1910_BUILD" \
  "$V1910_PROBE" "$work" "$PDP10_PREFIX"
port=$((41000+($$%1700)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
  "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(cd "$V1910_BUILD" && TERM=dumb timeout -k 3s "${V1910_TIMEOUT:-700}" \
  stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini") \
  > "$work/physical.log" 2>&1
rc=$?
set -e
tr -d '\r' < "$work/physical.log" > "$work/physical.clean"
if [ "$rc" -ne 0 ]; then
  tail -75 "$work/physical.clean" >&2
  echo "FAIL v1910 original physical simulator exit rc=$rc: $work" >&2
  exit 1
fi
python3 "$here/verify-physical-v1910.py" "$kit" "$V1910_BUILD" "$work"
echo "v1910 original foreign target parent EXIT evidence: $work"
