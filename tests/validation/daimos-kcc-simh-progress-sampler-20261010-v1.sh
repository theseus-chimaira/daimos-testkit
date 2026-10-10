#!/bin/sh
# Periodically stop a native KCC build in SIMH and record executed instruction
# history.  Uses the established PTY/FIFO interface rather than DevSpace stdin.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}" "${TMPDIR:?}"
work=${SAMPLE_WORK:-$TMPDIR/daimos-kcc-progress-20261010-v1}
mkdir -p "$work"
# A previous run can leave KCC markers in its transcript.  Never sample
# based on stale output before the harness recreates its run directory.
rm -rf "$work/run"
boot=${SAMPLE_BOOT:?set SAMPLE_BOOT to isolated SIMH boot.ini}
pty=${SAMPLE_PTY:?set SAMPLE_PTY to testkit PTY relay}
interval=${SAMPLE_INTERVAL:-30}
count=${SAMPLE_COUNT:-4}
cat > "$work/probes" <<'PROBES'
probe native-kcc-progress
command MAKE -C /OPTION/SOURCE/KCC B/CC-CPP.S
expect_timeout yes
timeout 190
end
PROBES
# A separate FIFO writer can inspect the simulator without interfering with
# the harness's DSH prompt parser.  Capture the debugger output in simh.log.
(
  log=$work/run/simh.log
  fifo=$work/run/simh.in
  n=0
  until grep -q 'KCC: KCC' "$log" 2>/dev/null; do
    [ -e "$fifo" ] || { sleep 1; continue; }
    sleep 1
  done
  while [ "$n" -lt "$count" ]; do
    sleep "$interval"
    printf '\005' > "$fifo"
    i=0
    until tail -n 8 "$log" | grep -q 'Simulation stopped\|Breakpoint, PC:'; do
      i=$((i + 1))
      [ "$i" -lt 20 ] || break
      sleep 1
    done
    printf 'show cpu history=64\nex PC\nex 40\nex 021157\nex 23452\n' > "$fifo"
    sleep 2
    printf 'go\n' > "$fifo"
    n=$((n + 1))
  done
) &
sampler=$!
cleanup_sampler() { kill "$sampler" 2>/dev/null || true; }
trap cleanup_sampler EXIT HUP INT TERM
"$(dirname "$0")/../../tools/daimos-simh-harness-v4.sh" \
 --daimos-repo "$DAIMOS_REPO" --dofile "$boot" --pty-run "$pty" \
 --login ROOT --probes "$work/probes" --work-dir "$work/run" \
 --markdown-report "$work/report.md" || :
kill "$sampler" 2>/dev/null || :
wait "$sampler" 2>/dev/null || :
[ -s "$work/run/simh.log" ]
echo "SIMH progress trace: $work/run/simh.log"
