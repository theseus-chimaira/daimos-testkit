#!/bin/sh
# Reproduce the first native KCC self-compile and retain its exit status.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}" "${TMPDIR:?}" "${KPARSE_BOOT:?}" "${KPARSE_PTY:?}"
work=${KPARSE_WORK:-$TMPDIR/daimos-kcc-native-exit-status-20261011-v1-$$}
if [ -e "$work" ]; then
        echo "refusing to overwrite evidence: $work" >&2
        exit 2
fi
mkdir -p "$work"
cat > "$work/probes" <<PROBES
probe native-kcc-exit-status
command MAKE -C /OPTION/SOURCE/KCC -F /OPTION/SOURCE/KCC/DAIMOS.MK BUILD/CC-CPP.S; ECHO KCC_EXIT_STATUS:\$?
terminal dsh
contains KCC_EXIT_STATUS:
not_matches ^UUO[[:space:]]+[0-7]+
timeout ${KPARSE_TIMEOUT:-900}
end
PROBES
printf 'boot=%s\nstart=%s\n' "$KPARSE_BOOT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$work/manifest.txt"
set +e
"$(dirname "$0")/../../tools/daimos-simh-harness-v6.sh" \
        --daimos-repo "$DAIMOS_REPO" --dofile "$KPARSE_BOOT" \
        --pty-run "$KPARSE_PTY" --login ROOT --probes "$work/probes" \
        --work-dir "$work/run" --markdown-report "$work/report.md" \
        --timeout-snapshot
rc=$?
set -e
printf 'exit_status=%s\nend=%s\n' "$rc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$work/manifest.txt"
printf 'retained_evidence=%s\n' "$work"
exit "$rc"
