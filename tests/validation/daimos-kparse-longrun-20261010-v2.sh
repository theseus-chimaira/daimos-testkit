#!/bin/sh
# Extended native KPARSE reproduction with retained SIMH evidence.
# Supply a boot.ini whose final command is 'go 020' (no following 'exit').
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}" "${TMPDIR:?}" "${KPARSE_BOOT:?}" "${KPARSE_PTY:?}"
work=${KPARSE_WORK:-$TMPDIR/daimos-kparse-longrun-20261010-v2-$$}
if [ -e "$work" ]; then
        echo "refusing to overwrite previous evidence: $work" >&2
        exit 2
fi
mkdir -p "$work"
cat > "$work/probes" <<PROBES
probe native-kparse-extended
command MAKE -C /OPTION/SOURCE/KCC B/CC-CPP.S
terminal dsh
timeout ${KPARSE_TIMEOUT:-1200}
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
