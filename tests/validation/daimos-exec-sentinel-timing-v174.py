#!/usr/bin/env python3
"""Bound EXEC guest execution independently of SIMH/kinit startup.

The '<' character is emitted by the test guest immediately before EXEC.
The interval is measured from host pipe arrival, not simulated cycles.
The boot phase has its own generous hard ceiling, while the time from
that marker to normal SIMH exit must stay within the EXEC deadline.
"""
import os
import selectors
import signal
import subprocess
import sys
import time


def main():
    if len(sys.argv) != 6:
        raise SystemExit("usage: exec-sentinel-timing OUT BOOT_S EXEC_S SIMH INI")
    outpath, boot_limit, exec_limit, simh, ini = sys.argv[1:]
    boot_limit, exec_limit = float(boot_limit), float(exec_limit)
    begin = time.monotonic()
    started_exec = None
    status = 1
    proc = subprocess.Popen([simh, ini], stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, start_new_session=True)
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    try:
        with open(outpath, 'wb') as output:
            while True:
                now = time.monotonic()
                if started_exec is None:
                    remaining = boot_limit - (now - begin)
                else:
                    remaining = exec_limit - (now - started_exec)
                if remaining <= 0:
                    phase = 'boot' if started_exec is None else 'EXEC'
                    print(f"{phase} deadline exceeded", file=sys.stderr)
                    return 124
                ready = selector.select(min(remaining, 0.2))
                for key, _ in ready:
                    chunk = os.read(key.fd, 4096)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    output.write(chunk)
                    output.flush()
                    if started_exec is None and b'<' in chunk:
                        started_exec = time.monotonic()
                if proc.poll() is not None and not selector.get_map():
                    status = proc.returncode
                    if started_exec is None:
                        print('pre-EXEC sentinel never appeared', file=sys.stderr)
                        return 1
                    print(f"EXEC elapsed={time.monotonic()-started_exec:.3f}s; "
                          f"boot elapsed={started_exec-begin:.3f}s")
                    return status
    finally:
        selector.close()
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGKILL)
        proc.wait()


if __name__ == '__main__':
    sys.exit(main())
