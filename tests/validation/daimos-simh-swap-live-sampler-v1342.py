#!/usr/bin/env python3
"""PDP-6 sampler preserving user text across Ctrl-E boundaries.

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
    'f07h_count', 'f07h_prepared', 'f07h_freed', 'f07h_error',
    'f07r_released', 'f07r_spinner_base', 'f07r_release_pressure',
    'f07q_calls', 'f07q_last', 'f07q_release_calls',
    'f07t_next',
    'armed', 'real_oom', 'fatal_busy', 'release', 'holder_return',
    'holder_enter', 'predispatch', 'ordinary_wait', 'fs_provider_ready',
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


def process_symbols(path):
    """Resolve only linked addresses; never infer a descriptor base."""
    requested = ('proc_table', 'proc_high_slot', 'proc_current_slot')
    found = {}
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[0] in requested:
            if fields[0] in found or not re.fullmatch(r'[0-7]{1,7}',
                                                     fields[1]):
                raise ValueError('invalid or duplicate process symbol')
            found[fields[0]] = int(fields[1], 8)
    if set(found) != set(requested):
        raise ValueError('missing linked process symbols')
    return found


def examined_word(text, address):
    """Return only one unambiguous SIMH examine value for an address."""
    pattern = r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]{1,12})' % address
    matches = re.findall(pattern, text)
    if len(matches) != 1:
        raise ValueError('missing or duplicate examined word %06o' % address)
    return int(matches[0], 8)


def process_table_address(text, symbols):
    base = examined_word(text, symbols['proc_table']) & 0o777777
    limit = examined_word(text, symbols['proc_high_slot'])
    current = examined_word(text, symbols['proc_current_slot'])
    if not (0 < base < 0o1000000 and 1 < limit <= 0o100 and
            0 <= current < limit and base + 3 * limit <= 0o1000000):
        raise ValueError('invalid linked process table range')
    # Capture all actual 64 process slots, without truncating a full
    # process table or modifying the kernel to publish snapshots.
    return base, limit, current


def process_descriptors(text, base, limit):
    words = [examined_word(text, base + offset)
             for offset in range(3 * limit)]
    states = ('FREE', 'NEW', 'RUN', 'SLEEP', 'WAIT', 'ZOMBIE',
              'STOP', 'OTHER')
    results = []
    for slot in range(limit):
        meta, vm, sched = words[slot * 3:slot * 3 + 3]
        state = states[(sched >> 33) & 7]
        resident = 'R' if vm & 0o777777 else 'D'
        size = (vm >> 18) & 0o777777
        flags = meta & 0o777777
        results.append('slot%02o=%s/%s:%06o:%06o' %
                       (slot, state, resident, size, flags))
    return results


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
    symbols = process_symbols(args.kcore_map) if args.kcore_map else None
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
    pending_sample = None
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
            def accept_guest(buf):
                # Preserve guest text from the running state AND the
                # interval between Ctrl-E and SIMH stop acknowledgement.
                # Only debugger text after the explicit stop marker is
                # excluded. Keep the original split-prompt filter.
                nonlocal running_tail, halt_seen, exit_tail, exit_seen
                running_tail = (running_tail + buf)[-128:]
                became_halted = (not halt_seen and
                    b'HALT instruction, PC:' in running_tail)
                if became_halted:
                    halt_seen = True
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
                    if len(postflight_pending) > 4:
                        guest.write(postflight_pending[:-4])
                        del postflight_pending[:-4]
                    break

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
                            accept_guest(buf)
                sample_complete = False
                if phase == 'interrupt':
                    marker = re.search(
                        rb'(?:sim>|Simulation stopped|Breakpoint, PC:)',
                        capture, re.I)
                    if marker is not None:
                        # A guest can write output after Ctrl-E was sent
                        # but before SIMH acknowledges the stop. Previous
                        # versions silently discarded such milestones.
                        prefix = bytes(capture[:marker.start()])
                        if prefix:
                            accept_guest(prefix)
                if phase == 'interrupt' and marker is not None:
                    commands = sample_commands(mapping)
                    if symbols:
                        commands.extend('ex %06o' % symbols[name] for name in
                                        ('proc_table', 'proc_high_slot',
                                         'proc_current_slot'))
                    write_all(master, ('\n'.join(commands) +
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
                        if symbols:
                            try:
                                base, limit, current = process_table_address(
                                    text, symbols)
                            except ValueError:
                                continue
                            pending_sample = (pc, values, base, limit,
                                              current)
                            commands = ['ex %06o' % (base + offset)
                                        for offset in range(3 * limit)]
                            write_all(master, ('\n'.join(commands) +
                                               '\n').encode('ascii'))
                            phase = 'inspect-slots'
                            deadline = time.monotonic() + 12
                            capture.clear()
                            continue
                        pending_sample = (pc, values, None, None, None)
                        sample_complete = True
                elif phase == 'inspect-slots':
                    text = capture.decode('ascii', errors='replace')
                    try:
                        descriptors = process_descriptors(
                            text, pending_sample[2], pending_sample[3])
                    except ValueError:
                        pass
                    else:
                        line = ('[v1332] process-table sample=%d '
                                'current=%02o base=%06o slots=%d %s\n' %
                                (taken + 1, pending_sample[4],
                                 pending_sample[2], pending_sample[3],
                                 ' '.join(descriptors)))
                        output.write(line.encode('ascii'))
                        sys.stdout.write(line)
                        sys.stdout.flush()
                        sample_complete = True
                if sample_complete:
                        pc, values = pending_sample[:2]
                        line = summary(taken + 1, pc, values)
                        # Retain v1306's established telemetry marker;
                        # the strict v1303 snapshot classifier uses it.
                        message = ('[v1306] ' + line + '\n').encode('ascii')
                        output.write(message)
                        sys.stdout.write(message.decode('ascii'))
                        sys.stdout.flush()
                        # Source-linked, strictly read-only test owner
                        # and independent user query observations.
                        diag = ('[v1342] sample=%d queries=%d '
                                'last_cooldown=%d release_calls=%d '
                                'released=%d owner_count=%d prepared=%d '
                                'freed=%d error=%d pinned_base=%06o '
                                'release_pressure=%d timer_next=%012o\n' %
                                (taken + 1, values['f07q_calls'],
                                 values['f07q_last'],
                                 values['f07q_release_calls'],
                                 values['f07r_released'],
                                 values['f07h_count'],
                                 values['f07h_prepared'],
                                 values['f07h_freed'],
                                 values['f07h_error'],
                                 values['f07r_spinner_base'],
                                 values['f07r_release_pressure'],
                                 values['f07t_next']))
                        dep = ('[v1342] sample=%d armed=%012o real_oom=%d '
                               'fatal_busy=%d release=%012o holder_return=%d '
                               'holder_enter=%d predispatch=%d ordinary_wait=%d '
                               'fs_provider_ready=%012o\n' %
                               (taken + 1, values['armed'], values['real_oom'],
                                values['fatal_busy'], values['release'],
                                values['holder_return'], values['holder_enter'],
                                values['predispatch'], values['ordinary_wait'],
                                values['fs_provider_ready']))
                        output.write(dep.encode('ascii'))
                        sys.stdout.write(dep)
                        sys.stdout.flush()
                        output.write(diag.encode('ascii'))
                        sys.stdout.write(diag)
                        sys.stdout.flush()
                        write_all(master, b'go\n')
                        pending_sample = None
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
                sys.stdout.write('[v1332] normal guest HALT after %d/%d '
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
    parser.add_argument('--kcore-map',
                        help='optional linked map for read-only live '
                             'process descriptor snapshots')
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
