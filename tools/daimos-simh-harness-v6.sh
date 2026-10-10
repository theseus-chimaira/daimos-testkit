#!/bin/sh
set -eu

# DAIMOS SIMH runtime harness without Python, pexpect, or Tcl expect.
# A tiny libc-only PTY relay gives SIMH the terminal its live CTY path requires;
# a persistent FIFO feeds that relay.  The probe language is deliberately
# line-oriented so the testkit needs no JSON parser or scripting runtime.

usage()
{
        cat <<'USAGE' >&2
usage: daimos-simh-harness-v6.sh --daimos-repo DIR --dofile FILE [options]
  --simh FILE              PDP-6 SIMH executable
  --pty-run FILE           PTY relay executable
  --tcp-run FILE           TCP relay executable for DCS0 transport
  --dcs-port PORT          drive login/probes through DCS0 on PORT
  --probes FILE            line-oriented probe file (default: inventory)
  --work-dir DIR           work directory
  --boot-timeout SEC       boot timeout, default 60
  --timeout SEC            command timeout, default 15
  --timeout-snapshot       interrupt SIMH and capture CPU history on timeout
  --login USER             log in through INIT/LOGIN before waiting for DSH
  --markdown-report FILE   markdown result report
USAGE
        exit 2
}

repo=
dofile=
simh=
probes=
work=
boot_timeout=60
default_timeout=15
markdown_report=daimos-runtime-report.md
pty_run=${DAIMOS_PTY_RUN:-}
tcp_run=${DAIMOS_TCP_RUN:-}
dcs_port=
login_user=
timeout_snapshot=no

while [ $# -gt 0 ]; do
        case "$1" in
        --daimos-repo) [ $# -ge 2 ] || usage; repo=$2; shift 2 ;;
        --dofile) [ $# -ge 2 ] || usage; dofile=$2; shift 2 ;;
        --simh) [ $# -ge 2 ] || usage; simh=$2; shift 2 ;;
        --pty-run) [ $# -ge 2 ] || usage; pty_run=$2; shift 2 ;;
        --tcp-run) [ $# -ge 2 ] || usage; tcp_run=$2; shift 2 ;;
        --dcs-port) [ $# -ge 2 ] || usage; dcs_port=$2; shift 2 ;;
        --probes) [ $# -ge 2 ] || usage; probes=$2; shift 2 ;;
        --work-dir) [ $# -ge 2 ] || usage; work=$2; shift 2 ;;
        --boot-timeout) [ $# -ge 2 ] || usage; boot_timeout=$2; shift 2 ;;
        --timeout) [ $# -ge 2 ] || usage; default_timeout=$2; shift 2 ;;
        --login) [ $# -ge 2 ] || usage; login_user=$2; shift 2 ;;
        --timeout-snapshot) timeout_snapshot=yes; shift ;;
        --markdown-report) [ $# -ge 2 ] || usage; markdown_report=$2; shift 2 ;;
        *) usage ;;
        esac
done

[ -n "$repo" ] || usage
[ -n "$dofile" ] || usage
[ -d "$repo" ] || { echo "invalid DAIMOS repository: $repo" >&2; exit 1; }
[ -f "$dofile" ] || { echo "missing SIMH command file: $dofile" >&2; exit 1; }
[ -n "$pty_run" ] && [ -x "$pty_run" ] || {
        echo "missing PTY relay executable: $pty_run" >&2
        exit 1
}
if [ -n "$dcs_port" ]; then
        [ -n "$tcp_run" ] && [ -x "$tcp_run" ] || {
                echo "missing TCP relay executable: $tcp_run" >&2
                exit 1
        }
fi

if [ -z "$simh" ]; then
        if [ -n "${SIMH_PDP6:-}" ]; then
                simh=$SIMH_PDP6
        elif [ -n "${PDP6_SIMH:-}" ]; then
                simh=$PDP6_SIMH
        elif [ -n "${PDP10_PREFIX:-}" ] && [ -x "$PDP10_PREFIX/bin/pdp6" ]; then
                simh=$PDP10_PREFIX/bin/pdp6
        else
                simh=`command -v pdp6 2>/dev/null || true`
        fi
fi
[ -n "$simh" ] && [ -x "$simh" ] || {
        echo "missing PDP-6 SIMH executable" >&2
        exit 1
}

: "${TMPDIR:?TMPDIR must be set}"
if [ -z "$work" ]; then
        work="$TMPDIR/daimos-simh-runtime-v6-$$"
fi
rm -rf "$work"
mkdir -p "$work"
log=$work/simh.log
fifo=$work/simh.in
dcs_log=$work/dcs0.log
dcs_fifo=$work/dcs0.in
results=$work/results.tsv
: > "$results"
mkfifo "$fifo"

child=
dcs_child=
cleanup()
{
        if [ -n "$dcs_child" ] && kill -0 "$dcs_child" 2>/dev/null; then
                kill "$dcs_child" 2>/dev/null || true
                wait "$dcs_child" 2>/dev/null || true
        fi
        if [ -n "$child" ] && kill -0 "$child" 2>/dev/null; then
                kill "$child" 2>/dev/null || true
                wait "$child" 2>/dev/null || true
        fi
        exec 3>&- 2>/dev/null || true
        exec 4>&- 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

# Open read/write so neither SIMH nor the writer observes a transient FIFO EOF.
exec 3<>"$fifo"
(
        cd "$repo"
        exec "$pty_run" "$simh" "$dofile" <"$fifo" >"$log" 2>&1
) &
child=$!

io_log=$log
if [ -n "$dcs_port" ]; then
        mkfifo "$dcs_fifo"
        exec 4<>"$dcs_fifo"
        "$tcp_run" 127.0.0.1 "$dcs_port" <"$dcs_fifo" >"$dcs_log" 2>&1 &
        dcs_child=$!
        io_log=$dcs_log
fi

log_size()
{
        if [ -f "$io_log" ]; then
                wc -c < "$io_log" | tr -d ' '
        else
                echo 0
        fi
}

alive()
{
        kill -0 "$child" 2>/dev/null
}

# Poll only bytes appended after START.  Integer seconds are enough for the
# testkit and keep this shell-only; ten polls per second gives good latency.
wait_marker()
{
        marker=$1
        start=$2
        seconds=$3
        ticks=$((seconds * 10))
        i=0
        while [ "$i" -le "$ticks" ]; do
                if [ -f "$io_log" ] && tail -c "+$((start + 1))" "$io_log" 2>/dev/null | grep -F "$marker" >/dev/null 2>&1; then
                        return 0
                fi
                alive || return 2
                i=$((i + 1))
                sleep 0.1
        done
        return 1
}

wait_exit()
{
        seconds=$1
        ticks=$((seconds * 10))
        i=0
        while [ "$i" -le "$ticks" ]; do
                alive || { wait "$child" 2>/dev/null || true; return 0; }
                i=$((i + 1))
                sleep 0.1
        done
        return 1
}

capture_since()
{
        start=$1
        out=$2
        end=`log_size`
        count=$((end - start))
        if [ "$count" -gt 0 ]; then
                dd if="$io_log" of="$out" bs=1 skip="$start" count="$count" status=none
        else
                : > "$out"
        fi
}

send_slow_line()
{
        text=$1
        while [ -n "$text" ]; do
                rest=${text#?}
                ch=${text%"$rest"}
                if [ -n "$dcs_port" ]; then
                        printf '%s' "$ch" >&4
                else
                        printf '%s' "$ch" >&3
                fi
                sleep 0.08
                text=$rest
        done
        if [ -n "$dcs_port" ]; then
                printf '\r' >&4
        else
                printf '\r' >&3
        fi
        sleep 0.15
}

send_dsh()
{
        text=$1
        limit=$2
        terminal=$3
        out=$4
        start=`log_size`
        if [ -n "$dcs_port" ]; then
                printf '%s\r' "$text" >&4
        else
                printf '%s\n' "$text" >&3
        fi
        case "$terminal" in
        dsh)
                rc=0
                wait_marker '# ' "$start" "$limit" || rc=$?
                capture_since "$start" "$out"
                return "$rc"
                ;;
        simh)
                rc=0
                wait_marker 'sim> ' "$start" "$limit" || rc=$?
                capture_since "$start" "$out"
                return "$rc"
                ;;
        eof)
                rc=0
                wait_exit "$limit" || rc=$?
                capture_since "$start" "$out"
                return "$rc"
                ;;
        *)
                echo "invalid terminal mode: $terminal" >&2
                return 3
                ;;
        esac
}

boot_start=0
rc=0
if [ -n "$login_user" ]; then
        if [ -n "$dcs_port" ]; then
                wait_marker 'Connected to the PDP6 simulator DCS device' \
                    "$boot_start" "$boot_timeout" || rc=$?
                if [ "$rc" -ne 0 ]; then
                        echo "DCS0 transport did not connect (rc=$rc); transcript: $dcs_log" >&2
                        tail -120 "$dcs_log" >&2 || true
                        exit 1
                fi
                start=`log_size`
                send_slow_line ""
                wait_marker 'LOGIN: ' "$start" "$boot_timeout" || rc=$?
                if [ "$rc" -eq 0 ]; then
                        # The first LOGIN observed after carrier can still be
                        # the prompt emitted before LOGIN entered its blocking
                        # read.  Force one more fresh prompt so credentials are
                        # never raced against terminal readiness.
                        start=`log_size`
                        send_slow_line ""
                        wait_marker 'LOGIN: ' "$start" "$boot_timeout" || rc=$?
                fi
        else
                wait_marker 'LOGIN: ' "$boot_start" "$boot_timeout" || rc=$?
        fi
        if [ "$rc" -ne 0 ]; then
                echo "LOGIN prompt not reached (rc=$rc); transcript: $io_log" >&2
                tail -120 "$io_log" >&2 || true
                exit 1
        fi
        start=`log_size`
        sleep 0.2
        send_slow_line "$login_user"
        wait_marker '# ' "$start" "$boot_timeout" || rc=$?
else
        wait_marker '# ' "$boot_start" "$boot_timeout" || rc=$?
fi
if [ "$rc" -ne 0 ]; then
        echo "DSH prompt not reached (rc=$rc); transcript: $io_log" >&2
        tail -120 "$io_log" >&2 || true
        exit 1
fi

if [ -z "$probes" ]; then
        probes=$work/inventory.probes
        cat > "$probes" <<'PROBES'
probe inventory-system-exec
command LS /SYSTEM/EXEC
end

probe inventory-option-exec
command LS /OPTION/EXEC
end
PROBES
fi
[ -f "$probes" ] || { echo "missing probe file: $probes" >&2; exit 1; }

probe_name=
probe_command=
probe_timeout=$default_timeout
probe_terminal=dsh
probe_expect_timeout=no
probe_rules=$work/rules
: > "$probe_rules"
pass=0
fail=0
total=0

run_probe()
{
        [ -n "$probe_name" ] || return 0
        [ -n "$probe_command" ] || {
                echo "probe $probe_name has no command" >&2
                exit 1
        }
        total=$((total + 1))
        output=$work/output.$total
        error=
        outcome=PASS

        # Setup commands are required to return to DSH, but their output is
        # intentionally excluded from the probe's assertions.
        while IFS= read -r setup; do
                [ -n "$setup" ] || continue
                setup_out=$work/setup.$total
                if ! send_dsh "$setup" "$default_timeout" dsh "$setup_out"; then
                        outcome=FAIL
                        error="setup command failed or timed out: $setup"
                        break
                fi
        done < "$work/setups"

        if [ "$outcome" = PASS ]; then
                rc=0
                send_dsh "$probe_command" "$probe_timeout" "$probe_terminal" "$output" || rc=$?
                # A timed-out native build must leave its evidence behind.
                # This is opt-in because ordinary SIMH command files often
                # contain "exit" after "go" and cannot accept a debugger
                # command following an interrupt.
                if [ "$rc" -eq 1 ] && [ "$timeout_snapshot" = yes ] && [ -z "$dcs_port" ]; then
                        before=`log_size`
                        printf '\005' >&3
                        if wait_marker 'sim> ' "$before" 8; then
                                printf 'show cpu history=96\nex PC\nex 40\nex 41\nshow cpu\n' >&3
                                sleep 2
                                capture_since "$before" "$work/timeout-debug.$total.txt"
                        else
                                printf 'SIMH did not return a debugger prompt\n' > "$work/timeout-debug.$total.txt"
                                capture_since "$before" "$work/timeout-interrupt.$total.txt"
                        fi
                        printf 'probe=%s\ncommand=%s\nlimit_seconds=%s\ntranscript=%s\n' \
                                "$probe_name" "$probe_command" "$probe_timeout" "$log" \
                                > "$work/timeout-metadata.$total.txt"
                fi
                if [ "$probe_expect_timeout" = yes ]; then
                        if [ "$rc" -eq 1 ]; then
                                rc=0
                        else
                                outcome=FAIL
                                error="expected timeout"
                        fi
                elif [ "$rc" -ne 0 ]; then
                        outcome=FAIL
                        if [ "$rc" -eq 1 ]; then error="timeout"; else error="SIMH exited before expected terminal"; fi
                fi
        else
                : > "$output"
        fi

        if [ "$outcome" = PASS ]; then
                raw_norm=$work/raw-norm.$total
                norm=$work/norm.$total
                tr -d '\r' < "$output" > "$raw_norm"
                first=
                IFS= read -r first < "$raw_norm" || true
                if [ "$first" = "$probe_command" ]; then
                        tail -n +2 "$raw_norm" > "$norm"
                else
                        cp "$raw_norm" "$norm"
                fi
                flat=$work/flat.$total
                tr '\n' ' ' < "$norm" > "$flat"
                while IFS=' ' read -r kind pattern; do
                        [ -n "$kind" ] || continue
                        case "$kind" in
                        contains)
                                grep -F -- "$pattern" "$norm" >/dev/null 2>&1 || { outcome=FAIL; error="missing expected text: $pattern"; break; }
                                ;;
                        not_contains)
                                if grep -F -- "$pattern" "$norm" >/dev/null 2>&1; then outcome=FAIL; error="forbidden text present: $pattern"; break; fi
                                ;;
                        matches)
                                grep -E -- "$pattern" "$flat" >/dev/null 2>&1 || { outcome=FAIL; error="missing expected match: $pattern"; break; }
                                ;;
                        not_matches)
                                if grep -E -- "$pattern" "$flat" >/dev/null 2>&1; then outcome=FAIL; error="forbidden match present: $pattern"; break; fi
                                ;;
                        line)
                                grep -E -- "$pattern" "$norm" >/dev/null 2>&1 || { outcome=FAIL; error="missing expected line match: $pattern"; break; }
                                ;;
                        not_line)
                                if grep -E -- "$pattern" "$norm" >/dev/null 2>&1; then outcome=FAIL; error="forbidden line match present: $pattern"; break; fi
                                ;;
                        *) echo "unknown probe rule: $kind" >&2; exit 1 ;;
                        esac
                done < "$probe_rules"
        fi

        if [ "$outcome" = PASS ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
        printf '%s\t%s\t%s\t%s\n' "$outcome" "$probe_name" "$probe_command" "$error" >> "$results"
        printf '%-12s %s: %s\n' "$outcome" "$probe_name" "$probe_command"

        # EOF and SIMH-terminal probes end the shared session by design.
        if [ "$probe_terminal" != dsh ] || [ "$probe_expect_timeout" = yes ]; then
                return 10
        fi
        return 0
}

: > "$work/setups"
stop_after_probe=no
while IFS= read -r raw || [ -n "$raw" ]; do
        case "$raw" in
        ''|'#'*) continue ;;
        esac
        key=${raw%% *}
        if [ "$raw" = "$key" ]; then value=; else value=${raw#* }; fi
        case "$key" in
        probe)
                if [ -n "$probe_name" ]; then echo "nested probe: $value" >&2; exit 1; fi
                probe_name=$value
                probe_command=
                probe_timeout=$default_timeout
                probe_terminal=dsh
                probe_expect_timeout=no
                : > "$probe_rules"
                : > "$work/setups"
                ;;
        setup) printf '%s\n' "$value" >> "$work/setups" ;;
        command) probe_command=$value ;;
        contains|not_contains|matches|not_matches|line|not_line)
                printf '%s %s\n' "$key" "$value" >> "$probe_rules"
                ;;
        timeout) probe_timeout=$value ;;
        terminal) probe_terminal=$value ;;
        expect_timeout) probe_expect_timeout=$value ;;
        status)
                echo "status assertions are not used by the current probe set; unsupported directive in $probes" >&2
                exit 1
                ;;
        end)
                rc=0
                run_probe || rc=$?
                probe_name=
                if [ "$rc" -eq 10 ]; then stop_after_probe=yes; break; fi
                [ "$rc" -eq 0 ] || exit "$rc"
                ;;
        *) echo "unknown probe directive: $key" >&2; exit 1 ;;
        esac
done < "$probes"
[ -z "$probe_name" ] || { echo "unterminated probe: $probe_name" >&2; exit 1; }

mkdir -p "`dirname "$markdown_report"`"
{
        echo '# DAIMOS SIMH runtime report'
        echo
        echo '## Summary'
        echo
        echo "- Total probes: $total"
        echo "- PASS: $pass"
        echo "- FAIL: $fail"
        echo
        echo '## Results'
        echo
        echo '| Outcome | Probe | Command | Error |'
        echo '|---|---|---|---|'
        tab=`printf "\t"`
        while IFS="$tab" read -r outcome name command error; do
                command=`printf '%s' "$command" | sed 's/|/\\|/g'`
                error=`printf '%s' "$error" | sed 's/|/\\|/g'`
                printf '| %s | %s | `%s` | %s |\n' "$outcome" "$name" "$command" "$error"
        done < "$results"
} > "$markdown_report"

[ "$fail" -eq 0 ]
