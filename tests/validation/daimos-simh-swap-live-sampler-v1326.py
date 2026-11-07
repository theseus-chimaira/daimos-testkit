#!/usr/bin/env python3
"""Bounded PDP-6 sampler, v1326 complete debugger-prompt isolation.

This never changes the guest executable or memory.  The host briefly
interrupts SIMH's console, examines linked KCORE words, then resumes.
Sampling overhead means this is diagnostic, not a timing benchmark.
"""

import argparse
import os
import pty
import re
import select
import signal
import subprocess
import sys
import tempfile
import termios
import time
from pathlib import Path


FIELDS = (
    'f07s_diag_sched_cursor', 'f07s_diag_swap_backoff',
    'f07s_diag_runq_head', 'f07s_diag_timer_clock',
    'f07s_diag_pressure', 'f07s_diag_fallback',
    'f07s_diag_victim_search', 'f07s_diag_reclaim_ok',
    'f07s_diag_reclaim_fail', 'f07s_diag_swapout_ok',
    'f07s_diag_swapout_fail', 'f07s_diag_swapin_ok',
    'f07s_diag_swapin_pressure', 'f07s_diag_swapin_fail',
    'f07s_diag_cooldown', 'f07s_diag_exchanged',
    'f07s_diag_restored',
    'f07a_calls', 'f07a_error', 'f07a_owner',
    'f07a_requested', 'f07a_extents', 'f07a_low_fit',
    'f07a_low_base_or_free', 'f07a_high_fit',
    'f07a_high_base_or_free', 'f07a_meta',
    'f07s_final_swap_blocks', 'f07s_final_backstore_used',
)


def addresses(path):
    values = {}
    for line in Path(path).read_text().splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0] in FIELDS:
            if parts[0] in values:
                raise ValueError('duplicate linked symbol ' + parts[0])
            if not re.fullmatch(r'[0-7]{1,7}', parts[1]):
                raise ValueError('invalid octal address')
            values[parts[0]] = parts[1]
    missing = sorted(set(FIELDS) - set(values))
    if missing:
        raise ValueError('missing required linked counters: ' + ','.join(missing))
    return values


def sample_commands(mapping):
    commands = ['ex PC']
    commands.extend('ex ' + mapping[name] for name in FIELDS)
    return commands


def parse_sample(text, mapping):
    values = {}
    for name, addr in mapping.items():
        pattern = (r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]{1,12})' %
                   int(addr, 8))
        matches = re.findall(pattern, text)
        if len(matches) != 1:
            raise ValueError('missing or ambiguous live counter: ' + name)
        values[name] = int(matches[0], 8)
    pcs = re.findall(r'(?m)^(?:sim>\s*)?PC:\s*([0-7]{1,7})', text)
    if len(pcs) != 1:
        raise ValueError('missing/ambiguous live PC')
    return int(pcs[0], 8), values


def summary(number, pc, values):
    def read(name):
        return values['f07s_diag_' + name]
    return ('sample=%d PC=%06o timer=%d cursor=%06o runq=%06o '
            'swap_backoff=%d swapout=%d swapin=%d pressure=%d '
            'cooldown=%d exchanges=%d alloc_failures=%d '
            'swap_blocks=%d backstore_blocks=%d' %
            (number, pc, read('timer_clock'), read('sched_cursor'),
             read('runq_head'), read('swap_backoff'),
             read('swapout_ok'), read('swapin_ok'), read('pressure'),
             read('cooldown'), read('exchanged'), values['f07a_calls'],
             values['f07s_final_swap_blocks'],
             values['f07s_final_backstore_used']))


def write_all(fd, buf):
    while buf:
        n = os.write(fd, buf)
        if n <= 0:
            raise OSError('console write failed')
        buf = buf[n:]


def run(args):
    mapping = addresses(args.addresses)
    if args.interval < 1 or args.count < 1 or args.timeout < 1:
        raise ValueError('interval, count and timeout must be positive')
    Path(args.log).parent.mkdir(parents=True, exist_ok=True)
    raw_path = args.raw_log or args.log + '.raw-v1306.log'
    if Path(raw_path).resolve() == Path(args.log).resolve():
        raise ValueError('raw and guest console output paths must differ')
    Path(raw_path).parent.mkdir(parents=True, exist_ok=True)
    # A normal F07 boot.ini has post-HALT diagnostic examines and EXIT.
    # Those commands must NOT execute when Ctrl-E temporarily stops GO:
    # SIMH otherwise advances the script and exits rather than prompting.
    original = Path(args.ini).read_text()
    lines = original.splitlines(keepends=True)
    go = [index for index, line in enumerate(lines)
          if line.strip().lower() == 'go 020']
    if len(go) != 1:
        raise ValueError('expected exactly one initial GO 020 command')
    boot = ''.join(lines[:go[0] + 1])
    post_halt = ''.join(lines[go[0] + 1:])
    if not post_halt.strip().lower().endswith('exit'):
        raise ValueError('expected normal post-HALT SIMH EXIT sequence')
    with tempfile.NamedTemporaryFile(mode='w', prefix='boot-v1306-',
                                     suffix='.ini', dir=Path(args.ini).parent,
                                     delete=False) as tmp:
        tmp.write(boot)
        boot_path = tmp.name
    master, slave = pty.openpty()
    attrs = termios.tcgetattr(slave)
    attrs[3] &= ~termios.ECHO
    termios.tcsetattr(slave, termios.TCSANOW, attrs)
    proc = subprocess.Popen([args.simh, boot_path], stdin=slave,
                            stdout=slave, stderr=slave, close_fds=True,
                            start_new_session=True)
    os.close(slave)
    os.set_blocking(master, False)
    start = time.monotonic()
    next_sample = start + args.interval
    taken = 0
    phase = 'running'
    deadline = None
    capture = bytearray()
    halt_seen = False
    exit_seen = False
    running_tail = b''
    exit_tail = b''
    # One continuous guest-only output filter must cover BOTH the
    # running guest after GO and the post-HALT SIMH examine script.
    # Without this, SIMH's 'sim> ' acknowledgement after each GO may
    # split a guest milestone stream and fool the original validator.
    postflight_pending = bytearray()
    try:
        with open(args.log, 'wb', buffering=0) as guest, \
                open(raw_path, 'wb', buffering=0) as output:
            while True:
                now = time.monotonic()
                exited = proc.poll() is not None and phase == 'running'
                if now - start > args.timeout:
                    raise TimeoutError('bounded SIMH live sampler timed out')
                if (phase == 'running' and not halt_seen and
                        taken < args.count and now >= next_sample):
                    # SIMH's standard console interrupt (Ctrl-E).
                    write_all(master, b'\x05')
                    phase = 'interrupt'
                    deadline = now + 5
                    capture.clear()
                ready, _, _ = select.select([master], [], [], 0.2)
                buf = b''
                if ready:
                    try:
                        buf = os.read(master, 65536)
                    except BlockingIOError:
                        buf = b''
                    except OSError:
                        buf = b''
                    if buf:
                        output.write(buf)
                        if phase != 'running':
                            capture.extend(buf)
                            if len(capture) > 65536:
                                capture = capture[-65536:]
                        elif phase == 'running':
                            # Preserve the original uninterrupted guest
                            # transcript for F07's strict milestone and
                            # final-MM assertions.  PTY postflight results
                            # include SIMH's interactive 'sim> ' prompt;
                            # strip it from the guest-only transcript.
                            running_tail = (running_tail + buf)[-128:]
                            became_halted = (not halt_seen and
                                b'HALT instruction, PC:' in running_tail)
                            if became_halted:
                                halt_seen = True
                                # Resume the original test's postflight
                                # examines and EXIT, retaining its resource
                                # accounting evidence.
                                write_all(master, post_halt.encode('ascii'))
                            if halt_seen:
                                exit_tail = (exit_tail + buf)[-128:]
                                if b'Goodbye' in exit_tail:
                                    exit_seen = True
                            postflight_pending.extend(buf)
                            while True:
                                prompt = postflight_pending.find(b'sim> ')
                                if prompt >= 0:
                                    guest.write(postflight_pending[:prompt])
                                    del postflight_pending[:prompt + 5]
                                    continue
                                # Preserve up to four bytes so a SIMH
                                # prompt split across PTY reads is still
                                # removed, never inserted into milestones.
                                if len(postflight_pending) > 4:
                                    guest.write(postflight_pending[:-4])
                                    del postflight_pending[:-4]
                                break
                if phase == 'interrupt' and re.search(
                        rb'(?:sim>|Simulation stopped|Breakpoint, PC:)',
                        capture, re.I):
                    write_all(master, ('\n'.join(sample_commands(mapping)) +
                                       '\n').encode('ascii'))
                    phase = 'inspect'
                    deadline = time.monotonic() + 8
                    capture.clear()
                elif phase == 'inspect':
                    text = capture.decode('ascii', errors='replace')
                    try:
                        pc, values = parse_sample(text, mapping)
                    except ValueError:
                        pass
                    else:
                        line = summary(taken + 1, pc, values)
                        message = ('[v1306] ' + line + '\n').encode('ascii')
                        output.write(message)
                        sys.stdout.write(message.decode('ascii'))
                        sys.stdout.flush()
                        write_all(master, b'go\n')
                        taken += 1
                        phase = 'running'
                        next_sample = time.monotonic() + args.interval
                        if args.stop_after_samples and taken == args.count:
                            output.write(b'[v1306] intentionally stopped '
                                         b'after diagnostic samples; '
                                         b'not a guest acceptance PASS\n')
                            return 0
                if phase != 'running' and time.monotonic() > deadline:
                    # Do not leave the simulated machine stopped after a
                    # failed diagnostic request.  Resume, but fail overall.
                    write_all(master, b'go\n')
                    raise RuntimeError('SIMH console sample did not complete')
                if exited and not buf:
                    if postflight_pending:
                        guest.write(postflight_pending)
                        postflight_pending.clear()
                    break
            if proc.returncode != 0:
                raise RuntimeError('SIMH exited with %s' % proc.returncode)
            if not halt_seen:
                raise RuntimeError('SIMH exited without observed guest HALT')
            if not exit_seen:
                raise RuntimeError('SIMH guest HALT without complete '
                                   'postflight EXIT')
            # A normal guest may HALT before the requested *maximum*
            # sample count. Never reject an otherwise completed guest
            # for lack of further read-only diagnostic interruptions.
            # The caller's original guest milestones/validator remain
            # authoritative; sampler exit 0 is not swap acceptance.
            if taken < args.count:
                sys.stdout.write('[v1326] normal guest HALT after %d/%d '
                                 'diagnostic samples; defer acceptance '
                                 'to original guest validators\n' %
                                 (taken, args.count))
        return 0
    finally:
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
        os.close(master)
        Path(boot_path).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simh', required=True)
    parser.add_argument('--ini', required=True)
    parser.add_argument('--addresses', required=True)
    parser.add_argument('--log', required=True,
                        help='canonical guest transcript (no debug pauses)')
    parser.add_argument('--raw-log',
                        help='full SIMH console/debugger transcript; default '
                             'is LOG.raw-v1306.log')
    parser.add_argument('--interval', type=int, default=30)
    parser.add_argument('--count', type=int, default=3)
    parser.add_argument('--timeout', type=int, default=240)
    parser.add_argument('--stop-after-samples', action='store_true',
                        help='diagnostic smoke mode only: intentionally '
                             'stop guest after collecting count samples')
    args = parser.parse_args()
    try:
        return run(args)
    except (OSError, RuntimeError, ValueError, TimeoutError) as exc:
        print('v1306: diagnostic failure: ' + str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
