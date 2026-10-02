#!/bin/sh
set -eu
fail() { echo "check-probe-format: $*" >&2; exit 1; }
[ "$#" -eq 1 ] || fail "usage: check-probe-format-v1.sh PROBES"
probes=$1
[ -f "$probes" ] || fail "missing probe file: $probes"
awk '
function bad(msg) { print "check-probe-format: " msg > "/dev/stderr"; exit 1 }
/^[[:space:]]*$/ || /^#/ { next }
{
    key=$1
    value=$0
    sub(/^[^[:space:]]+[[:space:]]*/, "", value)
    if (key == "probe") {
        if (inprobe) bad("nested probe at line " NR)
        if (value == "") bad("empty probe name at line " NR)
        if (seen[value]++) bad("duplicate probe name: " value)
        inprobe=1; command=0; ++count; next
    }
    if (!inprobe) bad("directive outside probe at line " NR)
    if (key == "command") {
        if (value == "") bad("empty command at line " NR)
        if (++command > 1) bad("multiple commands in probe at line " NR)
        next
    }
    if (key == "end") {
        if (!command) bad("probe without command at line " NR)
        inprobe=0; next
    }
    if (key == "setup" || key == "contains" || key == "not_contains" ||
        key == "matches" || key == "not_matches" || key == "line" ||
        key == "not_line") next
    if (key == "timeout") {
        if (value !~ /^[1-9][0-9]*$/) bad("invalid timeout at line " NR)
        next
    }
    if (key == "terminal") {
        if (value != "dsh" && value != "simh" && value != "eof")
            bad("invalid terminal at line " NR)
        next
    }
    if (key == "expect_timeout") {
        if (value != "yes" && value != "no") bad("invalid expect_timeout at line " NR)
        next
    }
    bad("unknown directive " key " at line " NR)
}
END {
    if (inprobe) bad("unterminated probe")
    if (!count) bad("empty probe file")
    print "probe format PASS: " count " probes"
}
' "$probes"
