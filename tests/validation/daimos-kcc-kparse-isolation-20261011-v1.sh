#!/bin/sh
# Isolate native KPARSE on the KPT stream produced by native KCPP.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}" "${TMPDIR:?}" "${KPARSE_BOOT:?}" "${KPARSE_PTY:?}"
work=${KPARSE_WORK:-$TMPDIR/daimos-kcc-kparse-isolation-20261011-v1-$$}
if [ -e "$work" ]; then
        echo "refusing to overwrite evidence: $work" >&2
        exit 2
fi
mkdir -p "$work"
cat > "$work/probes" <<PROBES
probe native-kcpp-source
command /OPTION/BASE/LIBEXEC/KCC/KCPP -R=/SCRATCH/A.KPT -I/OPTION/SOURCE/KCC/SELF/INCLUDE -I/OPTION/SOURCE/KCC/ABI /OPTION/SOURCE/KCC/CC.C; ECHO KCPP_STATUS:\$?
terminal dsh
contains KCPP_STATUS:0
timeout ${KPARSE_TIMEOUT:-900}
end
probe native-kparse-source
command /OPTION/BASE/LIBEXEC/KCC/KPARSE -R=/SCRATCH/B.KIR /SCRATCH/A.KPT; ECHO KPARSE_STATUS:\$?
terminal dsh
contains KPARSE_STATUS:0
not_contains KIR graph allocation/identity failure
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
