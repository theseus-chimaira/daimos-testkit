#!/bin/sh
# Execute the actual production test runner's F07 milestone condition with
# contaminated SIMH banners and exact-good/bad guest marker streams.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-f07-milestone-scope-v1496.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 - "$self/daimos-oom-requester-live-v1075.sh" "$work" <<'PY'
from pathlib import Path
import sys

source, work = Path(sys.argv[1]), Path(sys.argv[2])
text = source.read_text()
start = ('if [ "$f07_swapslots" = 1 ]; then\n'
         '    # Distinguish genuine slow disk swapping')
if text.count(start) != 1:
    raise AssertionError('real F07 milestone block moved')
chunk = text.split(start, 1)[1]
if '\nfi\n' not in chunk:
    raise AssertionError('real F07 milestone block has no end')
block = start + chunk.split('\nfi\n', 1)[0] + '\nfi\n'
if 'guest_milestones=${text#*<}' not in block:
    raise AssertionError('F07 milestone scoping omitted')
runner = '''#!/bin/sh
set -eu
work=%s
f07_swapslots=1
extra_count=2
text=$(cat "$work/input")
%s
printf 'PASS strict-milestones\\n'
''' % (str(work), block)
(work / 'run.sh').write_text(runner)
PY

good='PDP6 simulator git commit abcd+uncommitted-changes DAIMON<D6FS<+~+~HALT instruction, PC: 020000 Goodbye'
printf '%s\n' "$good" > "$work/input"
sh "$work/run.sh" > "$work/good.log" 2>&1 || {
    cat "$work/good.log" >&2
    exit 1
}
grep -q 'PASS strict-milestones' "$work/good.log"
echo 'PASS v1496: contaminated SIMH banner does not count as RUN child'

# Real physical v1494 evidence: 19 plus signs in the whole transcript,
# exactly 18 after the F07 '<' marker, and 18 reaps. The regression
# above proves the 2-child form without depending on a retained guest.
for scenario in missing-start extra-guest-ack missing-guest-ack \
                missing-reap; do
    case "$scenario" in
        missing-start)
            input='SIMH banner+dirty DAIMON +~+~HALT instruction' ;;
        extra-guest-ack)
            input='SIMH banner+dirty DAIMON<++~+~HALT instruction' ;;
        missing-guest-ack)
            input='SIMH banner+dirty DAIMON<+~HALT instruction' ;;
        missing-reap)
            input='SIMH banner+dirty DAIMON<+~+HALT instruction' ;;
    esac
    printf '%s\n' "$input" > "$work/input"
    if sh "$work/run.sh" > "$work/$scenario.log" 2>&1; then
        echo "FAIL v1496: $scenario falsely accepted" >&2
        exit 1
    fi
done
echo 'PASS v1496: missing start, false child, missing ack/reap rejected'
