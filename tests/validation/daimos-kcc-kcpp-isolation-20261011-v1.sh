#!/bin/sh
# Run the first native compiler phase without the KCC driver or MAKE.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}" "${TMPDIR:?}" "${KPARSE_BOOT:?}" "${KPARSE_PTY:?}"
work=${KPARSE_WORK:-$TMPDIR/daimos-kcc-kcpp-isolation-20261011-v1-$$}
if [ -e "$work" ]; then
        echo "refusing to overwrite evidence: $work" >&2
        exit 2
fi
mkdir -p "$work"
cat > "$work/probes" <<PROBES
probe native-kcpp-isolation
command /OPTION/BASE/LIBEXEC/KCC/KCPP -R=/SCRATCH/A.KPT -I/OPTION/SOURCE/KCC/SELF/INCLUDE -I/OPTION/SOURCE/KCC/ABI /OPTION/SOURCE/KCC/CC.C; ECHO KCPP_STATUS:\$?
terminal dsh
contains KCPP_STATUS:0
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
