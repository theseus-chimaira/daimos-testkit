#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

MAKE_CMD=${MAKE:-make}
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
testkit_repo=$(CDPATH= cd -- "$script_dir/../.." && pwd -P)
matrix=${DAIMOS_REGRESSION_MATRIX:-$script_dir/daimos-regression-matrix-v1.tsv}
state=${DAIMOS_REGRESSION_STATE:-$TMPDIR/daimos-regression-sweep-v1.state}
log_dir=${DAIMOS_REGRESSION_LOG_DIR:-$TMPDIR/daimos-regression-sweep-v1.logs}
restart=0
status_only=0

usage()
{
        echo "usage: $0 [--restart|--status]" >&2
        exit 2
}

case "${1-}" in
"") ;;
--restart) restart=1 ;;
--status) status_only=1 ;;
*) usage ;;
esac

fingerprint_repo()
{
        repo=$1
        (
                cd "$repo"
                head=$(git rev-parse HEAD)
                diff=$(git diff --binary HEAD -- . | cksum | awk '{print $1 "-" $2}')
                printf '%s-%s\n' "$head" "$diff"
        )
}

daimos_fp=$(fingerprint_repo "$DAIMOS_REPO")
testkit_fp=$(fingerprint_repo "$testkit_repo")
matrix_fp=$(cksum "$matrix" | awk '{print $1 "-" $2}')

mkdir -p "$log_dir"
if [ "$restart" -ne 0 ]; then
        rm -f "$state"
fi
touch "$state"

passed_line()
{
        id=$1
        awk -F '\t' -v id="$id" '$1 == id && $2 == "PASS" { line=$0 } END { if (line != "") print line }' "$state"
}

record_pass()
{
        id=$1
        tmp=$state.tmp.$$
        awk -F '\t' -v id="$id" '$1 != id' "$state" > "$tmp"
        printf '%s\tPASS\t%s\t%s\t%s\n' \
            "$id" "$daimos_fp" "$testkit_fp" "$matrix_fp" >> "$tmp"
        mv "$tmp" "$state"
}

record_fail()
{
        id=$1
        rc=$2
        tmp=$state.tmp.$$
        awk -F '\t' -v id="$id" '$1 != id' "$state" > "$tmp"
        printf '%s\tFAIL\t%s\t%s\t%s\t%s\n' \
            "$id" "$daimos_fp" "$testkit_fp" "$matrix_fp" "$rc" >> "$tmp"
        mv "$tmp" "$state"
}

same_revision()
{
        line=$1
        old_daimos=$(printf '%s\n' "$line" | awk -F '\t' '{print $3}')
        old_testkit=$(printf '%s\n' "$line" | awk -F '\t' '{print $4}')
        old_matrix=$(printf '%s\n' "$line" | awk -F '\t' '{print $5}')
        [ "$old_daimos" = "$daimos_fp" ] &&
            [ "$old_testkit" = "$testkit_fp" ] &&
            [ "$old_matrix" = "$matrix_fp" ]
}

print_row()
{
        id=$1
        subsystem=$2
        description=$3
        line=$(passed_line "$id")
        if [ -z "$line" ]; then
                if awk -F '\t' -v id="$id" '$1 == id && $2 == "FAIL" { found=1 } END { exit !found }' "$state"; then
                        mark=FAIL
                else
                        mark=TODO
                fi
        elif same_revision "$line"; then
                mark=PASS
        else
                mark=OLD
        fi
        printf '%-4s %-3s %-11s %s\n' "$mark" "$id" "$subsystem" "$description"
}

printf '%s\n' 'DAIMOS regression sweep v1'
printf '%s\n' "matrix: $matrix"
printf '%s\n' "state:  $state"

if [ "$status_only" -ne 0 ]; then
        total=0
        complete=0
        current=0
        while IFS='|' read -r id subsystem targets description; do
                case "$id" in ''|'#'*) continue ;; esac
                total=$((total + 1))
                line=$(passed_line "$id")
                if [ -n "$line" ]; then
                        complete=$((complete + 1))
                        if same_revision "$line"; then
                                current=$((current + 1))
                        fi
                fi
                print_row "$id" "$subsystem" "$description"
        done < "$matrix"
        printf 'completed: %s/%s; current-revision: %s/%s\n' \
            "$complete" "$total" "$current" "$total"
        exit 0
fi

mixed=0
total=0
failures=0
while IFS='|' read -r id subsystem targets description; do
        case "$id" in ''|'#'*) continue ;; esac
        total=$((total + 1))
        line=$(passed_line "$id")
        if [ -n "$line" ]; then
                if ! same_revision "$line"; then
                        mixed=1
                fi
                print_row "$id" "$subsystem" "$description"
                continue
        fi

        log=$log_dir/$id.log
        printf 'RUN  %-3s %-11s %s\n' "$id" "$subsystem" "$description"
        printf '     targets: %s\n' "$targets"
        set +e
        "$MAKE_CMD" -k -C "$testkit_repo" $targets \
            PDP10_PREFIX="$PDP10_PREFIX" DAIMOS_REPO="$DAIMOS_REPO" \
            TMPDIR="$TMPDIR" >"$log" 2>&1
        rc=$?
        set -e
        if [ "$rc" -ne 0 ]; then
                record_fail "$id" "$rc"
                cat "$log"
                printf 'FAIL %-3s %-11s rc=%s log=%s\n' \
                    "$id" "$subsystem" "$rc" "$log" >&2
                failures=$((failures + 1))
                continue
        fi
        record_pass "$id"
        printf 'PASS %-3s %-11s %s\n' "$id" "$subsystem" "$description"
done < "$matrix"

if [ "$failures" -ne 0 ]; then
        printf 'daimos-regression-resume-v1: FAIL (%s failing rows; resume reruns only non-PASS rows)\n' \
            "$failures" >&2
        exit 1
fi

if [ "$mixed" -ne 0 ]; then
        printf '%s\n' "daimos-regression-resume-v1: PASS ($total/$total rows, mixed source revisions)"
        printf '%s\n' 'run make regression-restart for a strict single-revision acceptance result'
else
        printf '%s\n' "daimos-regression-resume-v1: PASS ($total/$total rows, current revision)"
fi
