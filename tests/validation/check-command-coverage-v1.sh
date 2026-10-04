#!/bin/sh
set -eu

fail()
{
    echo "check-command-coverage: $*" >&2
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
makefile=$DAIMOS_REPO/userland/Makefile
[ -f "$makefile" ] || fail "missing userland Makefile: $makefile"

commands=$(awk '''
BEGIN { take = 0 }
/^COMMAND_PROGRAMS[[:space:]]*=/ {
        take = 1
        sub(/^[^=]*=[[:space:]]*/, "")
}
take {
        line = $0
        cont = sub(/[[:space:]]*\\[[:space:]]*$/, "", line)
        n = split(line, a, /[[:space:]]+/)
        for (i = 1; i <= n; ++i)
                if (a[i] ~ /^[A-Z0-9][A-Z0-9.]*$/)
                        print a[i]
        take = cont
}
''' "$makefile" | sort -u)
commands=$(printf '%s\n%s\n' "$commands" MOUNT.TSFS | sort -u)
[ -n "$commands" ] || fail "no standalone command inventory found in $makefile"

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
    echo "missing standalone command coverage: $missing" >&2
fi
if [ -n "$obsolete" ]; then
    echo "obsolete standalone executable probes remain:" >&2
    printf '%s\n' "$obsolete" | sed 's/^/  /' >&2
fi
[ -z "$missing" ] && [ -z "$obsolete" ] || exit 1
count=$(printf '%s\n' "$commands" | wc -l | tr -d ' ')
echo "standalone command coverage PASS: $count commands"
