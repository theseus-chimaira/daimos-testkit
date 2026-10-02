#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
: "${PTY_RUN:?PTY_RUN must be set}"
: "${TCP_RUN:?TCP_RUN must be set}"

BOOT_DIR=$DAIMOS_REPO/system/boot/pdp6
WORK=$TMPDIR/daimos-root-login-lifecycle-v1-$$
INITTAB=$WORK/inittab-dcs0
sim_pid=
tcp_pid=

cleanup_children()
{
        if [ -n "$tcp_pid" ] && kill -0 "$tcp_pid" 2>/dev/null; then
                kill "$tcp_pid" 2>/dev/null || true
                wait "$tcp_pid" 2>/dev/null || true
        fi
        if [ -n "$sim_pid" ] && kill -0 "$sim_pid" 2>/dev/null; then
                kill "$sim_pid" 2>/dev/null || true
                wait "$sim_pid" 2>/dev/null || true
        fi
        sim_pid=
        tcp_pid=
}

cleanup()
{
        cleanup_children
        rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$WORK"
printf '%s\n' '1:RESPAWN:/SYSTEM/EXEC/LOGIN' > "$INITTAB"

log_size()
{
        if [ -f "$1" ]; then wc -c < "$1" | tr -d ' '; else echo 0; fi
}

wait_new()
{
        file=$1
        marker=$2
        start=$3
        ticks=$4
        i=0
        while [ "$i" -lt "$ticks" ]; do
                if tail -c "+$((start + 1))" "$file" 2>/dev/null | \
                    grep -F "$marker" >/dev/null 2>&1; then
                        return 0
                fi
                kill -0 "$sim_pid" 2>/dev/null || return 1
                i=$((i + 1))
                sleep 0.1
        done
        return 1
}

send_slow()
{
        fd=$1
        text=$2
        while [ -n "$text" ]; do
                rest=${text#?}
                ch=${text%"$rest"}
                printf '%s' "$ch" >&"$fd"
                sleep 0.08
                text=$rest
        done
        printf '\r' >&"$fd"
        sleep 0.15
}

run_root()
{
        root=$1
        n=$2
        build=$WORK/build-$root
        run=$WORK/run-$root
        cty=$run/cty.log
        dcs=$run/dcs.log
        fifo=$run/dcs.in
        dcs_port=$((21000 + ($$ % 1000) * 4 + n))
        ge_port=$((dcs_port + 12000))

        mkdir -p "$run"
        PATH="$PDP10_PREFIX/bin:$PATH" make -C "$BOOT_DIR" image \
            BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
            BOOT=dsk ROOT="$root" SYSTEM_INITTAB_TEXT="$INITTAB" \
            SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null

        mkfifo "$fifo"
        exec 3<>"$fifo"
        (
                cd "$DAIMOS_REPO"
                TERM=dumb exec "$PTY_RUN" "$PDP10_PREFIX/bin/pdp6" \
                    "$build/boot.ini" </dev/null
        ) >"$cty" 2>&1 &
        sim_pid=$!
        "$TCP_RUN" 127.0.0.1 "$dcs_port" <"$fifo" >"$dcs" 2>&1 &
        tcp_pid=$!

        wait_new "$dcs" 'Connected to the PDP6 simulator DCS device' 0 600 || {
                cat "$cty" "$dcs" >&2 || true
                echo "root-login-$root: DCS0 transport missing" >&2
                return 1
        }

        # The initial prompt can precede TCP carrier.  Force a fresh prompt.
        start=`log_size "$dcs"`
        send_slow 3 ''
        wait_new "$dcs" 'LOGIN: ' "$start" 3000 || {
                cat "$cty" "$dcs" >&2 || true
                echo "root-login-$root: LOGIN prompt missing" >&2
                return 1
        }

        # Reject a nonexistent account and reprompt on the same terminal.
        start=`log_size "$dcs"`
        send_slow 3 NOSUCH
        wait_new "$dcs" 'LOGIN INCORRECT' "$start" 3000 || {
                cat "$cty" "$dcs" >&2 || true
                echo "root-login-$root: invalid account was not rejected" >&2
                return 1
        }
        wait_new "$dcs" 'LOGIN: ' "$start" 3000 || {
                cat "$cty" "$dcs" >&2 || true
                echo "root-login-$root: no reprompt after invalid account" >&2
                return 1
        }

        # Valid ROOT login proves the controlling terminal is usable by DSH.
        start=`log_size "$dcs"`
        send_slow 3 ROOT
        wait_new "$dcs" 'DSH V1' "$start" 3000 || {
                cat "$cty" "$dcs" >&2 || true
                echo "root-login-$root: ROOT did not enter DSH" >&2
                return 1
        }
        start=`log_size "$dcs"`
        send_slow 3 PWD
        wait_new "$dcs" '# ' "$start" 3000 || {
                cat "$cty" "$dcs" >&2 || true
                echo "root-login-$root: PWD did not return" >&2
                return 1
        }
        tail -c "+$((start + 1))" "$dcs" | tr -d '\r' | \
            grep -Fx '/' >/dev/null 2>&1 || {
                cat "$cty" "$dcs" >&2 || true
                echo "root-login-$root: configured ROOT home is not /" >&2
                return 1
        }

        # EXIT must terminate the shell/login process; PID 1 must respawn LOGIN.
        start=`log_size "$dcs"`
        send_slow 3 EXIT
        wait_new "$dcs" 'LOGIN: ' "$start" 3000 || {
                cat "$cty" "$dcs" >&2 || true
                echo "root-login-$root: LOGIN did not respawn after EXIT" >&2
                return 1
        }
        start=`log_size "$dcs"`
        send_slow 3 ROOT
        wait_new "$dcs" 'DSH V1' "$start" 3000 || {
                cat "$cty" "$dcs" >&2 || true
                echo "root-login-$root: second ROOT login failed" >&2
                return 1
        }
        start=`log_size "$dcs"`
        send_slow 3 'ECHO RELOGINOK'
        wait_new "$dcs" 'RELOGINOK' "$start" 3000 || {
                cat "$cty" "$dcs" >&2 || true
                echo "root-login-$root: respawned session is not usable" >&2
                return 1
        }

        exec 3>&-
        cleanup_children
        printf '%s\n' "root-login-$root: PASS (invalid login, ROOT, HOME, logout/respawn, relogin)"
}

run_root disk 1
run_root drum 2
run_root tape 3

printf '%s\n' 'root-login-lifecycle: PASS (DSK/D6FS, DRM/D6FS, DTC/TSFS)'
