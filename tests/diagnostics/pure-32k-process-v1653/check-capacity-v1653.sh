#!/bin/sh
# Compare actual failed 32K KINIT PURE ON/OFF link/build results.
# These are ORIGINAL link/host safety refusals, not a physical 32K PASS.
set -eu
: "${PURE_32K_ON_V1653:?original v1653 32K PURE ON workdir required}"
: "${PURE_32K_OFF_V1653:?original v1653 32K PURE OFF workdir required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-32k-capacity-v1653.XXXXXX")
trap 'echo "v1653 32K KINIT evidence: $work"' EXIT HUP INT TERM
on=$PURE_32K_ON_V1653
off=$PURE_32K_OFF_V1653
test -e "$on/build/.kinit-pure-v1611-mode-1"
test -e "$off/build/.kinit-pure-v1611-mode-0"
test -s "$on/user/init-v1653.dxr"
cmp -s "$on/build/kcore.map" "$off/build/kcore.map"
cmp -s "$on/build/kcore.stream" "$off/build/kcore.stream"

run_audit() {
    python3 "$here/audit-capacity-v1653.py" \
        "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8"
}
om="$on/build/kinit.map"
fm="$off/build/kinit.map"
oc="$on/build/kcore.map"
fc="$off/build/kcore.map"
os="$on/build/kcore.stream"
fs="$off/build/kcore.stream"
ol="$on/build-v1653.log"
fl="$off/build.log"
run_audit "$om" "$fm" "$oc" "$fc" "$os" "$fs" "$ol" "$fl" \
    >"$work/original-v1653.log"
cat "$work/original-v1653.log"

python3 - "$om" "$ol" "$os" "$work" <<'PY'
from pathlib import Path
import sys

om, ol, original_core, work = (Path(p) for p in sys.argv[1:])
map_source = om.read_text(encoding="ascii")
old = "__kinit_image_end                113621"
new = "__kinit_image_end                077400"
assert map_source.count(old) == 1
(work / "false-fit-v1653.map").write_text(
    map_source.replace(old, new, 1), encoding="ascii")
log_source = ol.read_text(encoding="ascii")
needle = "KINIT image end 113621"
assert log_source.count(needle) == 1
(work / "false-log-v1653.log").write_text(
    log_source.replace(needle, "KINIT image end 077400", 1),
    encoding="ascii")
(work / "false-kcore-v1653.stream").write_bytes(
    original_core.read_bytes() + b"0")
PY
for bad in fit log kcore; do
    case $bad in
    fit) map="$work/false-fit-v1653.map"; log="$ol"; stream="$os" ;;
    log) map="$om"; log="$work/false-log-v1653.log"; stream="$os" ;;
    kcore) map="$om"; log="$ol"; stream="$work/false-kcore-v1653.stream" ;;
    esac
    if run_audit "$map" "$fm" "$oc" "$fc" "$stream" "$fs" \
        "$log" "$fl" >"$work/rejected-$bad-v1653.log" 2>&1; then
        echo "FAIL v1653: false $bad KINIT input accepted" >&2
        exit 1
    fi
    if ! grep -q '^FAIL v1653 32K KINIT capacity audit:' \
        "$work/rejected-$bad-v1653.log"; then
        cat "$work/rejected-$bad-v1653.log" >&2
        exit 1
    fi
    echo "PASS v1653: false $bad KINIT witness rejected"
done
echo 'PASS v1653: original source-matched 32K KINIT ON/OFF size diagnosis'
