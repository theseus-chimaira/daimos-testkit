#!/bin/sh
# v1656: current original PDP-6 DTFS raw read/write/cache and volume-ID
# integration plus modern V2 intent and physical identity regressions.
set -eu
: "${DAIMOS_REPO:?original DAIMOS checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-integration-v1656.XXXXXX")
trap 'echo "v1656 original DTFS integration evidence: $work"' EXIT HUP INT TERM

run_case() {
    label=$1
    filename=$2
    echo "v1656: running source-linked $label"
    sh "$kit/tests/validation/$filename" >"$work/$label.log" 2>&1 || {
        tail -70 "$work/$label.log" >&2
        echo "FAIL v1656: $label on current original source" >&2
        exit 1
    }
    grep -q '^PASS ' "$work/$label.log"
    echo "PASS v1656: source-linked $label"
}

# Recovered old original full wrapper/cache/identity integration.
run_case raw-io-bcache-v1518 daimos-dtfs-io-error-cache-v1518.sh
run_case mounted-id-v1522 daimos-dtfs-mounted-id-v1522.sh
# Independent actual DTVOL1/DTVOL2, DIRTY, mounted MM gate and discard.
run_case modern-v1655 dtfs-modern-v1655/run-v1655.sh

python3 - "$work" "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys

work, repo = (Path(x) for x in sys.argv[1:])
counts = (("raw-io-bcache-v1518.log", 4),
          ("mounted-id-v1522.log", 8))
for name, count in counts:
    data = (work / name).read_text(encoding="ascii").splitlines()
    assert len([line for line in data if line.startswith("PASS ") and
                ("rejected " in line)]) == count, (name, count)
modern = (work / "modern-v1655.log").read_text(encoding="ascii")
assert "39 separately executed unsafe source mutants rejected" in modern
source = (repo / "system/kernel/fs/dtfs_runtime.s").read_text(
    encoding="ascii")
gate = (repo / "system/kernel/fs/dtfs_intent_mount_gate_v1561.s"
        ).read_text(encoding="ascii")
assert source.count("pushj   17,dtfs_intent_mount_gate_v1561") == 1
assert gate.count("dtfs_intent_mount_gate_v1561:") == 1
print("PASS v1656: original 2 integration tests, 82 modern cases, "
      "51 executed unsafe mutations")
PY
