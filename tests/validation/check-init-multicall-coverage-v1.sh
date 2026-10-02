#!/bin/sh
set -eu

fail()
{
    echo "check-init-multicall-coverage: $*" >&2
    exit 1
}

DAIMOS_REPO=
PROBES=
SCRIPTS=
while [ "$#" -gt 0 ]; do
    case $1 in
    --daimos-repo)
        [ "$#" -ge 2 ] || fail "missing --daimos-repo value"
        DAIMOS_REPO=$2
        shift 2
        ;;
    --probes)
        [ "$#" -ge 2 ] || fail "missing --probes value"
        PROBES="${PROBES}${PROBES:+ }$2"
        shift 2
        ;;
    --script)
        [ "$#" -ge 2 ] || fail "missing --script value"
        SCRIPTS="${SCRIPTS}${SCRIPTS:+ }$2"
        shift 2
        ;;
    *) fail "unknown argument: $1" ;;
    esac
done
[ -n "$DAIMOS_REPO" ] || fail "--daimos-repo is required"
[ -n "$PROBES$SCRIPTS" ] || fail "at least one coverage source is required"
source=$DAIMOS_REPO/userland/exec/commands.c
[ -f "$source" ] || fail "missing current INIT multicall source: $source"

commands=$(sed -n 's/.*cmd_name_eq(argv\[0\], "\([A-Z0-9][A-Z0-9.]*\)").*/\1/p' "$source" | sort -u)
[ -n "$commands" ] || fail "no INIT multicall commands found in $source"

covered=
for file in $PROBES; do
    [ -f "$file" ] || fail "missing probe file: $file"
    names=$(sed -n 's/^command[[:space:]][[:space:]]*\([^[:space:]][^[:space:]]*\).*/\1/p' "$file" || true)
    covered="${covered}${covered:+
}${names}"
done
for file in $SCRIPTS; do
    [ -f "$file" ] || fail "missing integration script: $file"
    names=$(sed -n -e 's/^[[:space:]]*# covers-command[[:space:]][[:space:]]*\([A-Z0-9][A-Z0-9.]*\).*/\1/p' "$file" || true)
    covered="${covered}${covered:+
}${names}"
done
covered=$(printf '%s\n' "$covered" | tr '[:lower:]' '[:upper:]' | sed '/^$/d' | sort -u)

missing=
for command in $commands; do
    if ! printf '%s\n' "$covered" | grep -Fx "$command" >/dev/null 2>&1; then
        missing="${missing}${missing:+ }$command"
    fi
done
obsolete=
for file in $PROBES; do
    old=$(sed -n 's/^command[[:space:]][[:space:]]*//p' "$file" | grep -E '/(SYSTEM|OPTION)/EXEC/' || true)
    obsolete="${obsolete}${obsolete:+
}${old}"
done
if [ -n "$missing" ]; then
    echo "missing INIT multicall coverage: $missing" >&2
fi
if [ -n "$obsolete" ]; then
    echo "obsolete standalone executable probes remain:" >&2
    printf '%s\n' "$obsolete" | sed 's/^/  /' >&2
fi
[ -z "$missing" ] && [ -z "$obsolete" ] || exit 1
count=$(printf '%s\n' "$commands" | wc -l | tr -d ' ')
echo "INIT multicall coverage PASS: $count commands"
