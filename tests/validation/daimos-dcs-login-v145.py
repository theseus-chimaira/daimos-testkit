#!/usr/bin/env python3
"""Verify a carrier-first DCS0 LOGIN and ROOT shell on PDP-6 SIMH.

Use fresh disk images and a unique TCP port for every test invocation.
The CPU pauses in INIT's first WAIT to allow the DCS socket to connect
before LOGIN emits its one initial prompt. This avoids losing output to
SIMH's disconnected-line transmit behavior without modifying DAIMOS.
"""
import os
from pathlib import Path
import socket
import subprocess
import sys
import time


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    require(len(sys.argv) == 2 and sys.argv[1] in ("64", "128"),
            "usage: daimos-dcs-login-v145.py 64|128")
    size = int(sys.argv[1])
    env = os.environ.copy()
    for key in ("TMPDIR", "DAIMOS_REPO", "PDP10_PREFIX"):
        require(env.get(key), f"{key} is required")
    work = Path(env["TMPDIR"]) / f"daimos-dcs-login-v145-{size}k-{os.getpid()}"
    boot = work / "build/system/boot/pdp6"
    work.mkdir(parents=True)
    print(f"Preserving build and logs: {work}", flush=True)
    port = 23000 + os.getpid() % 7000
    cmd = ["make", "-C", str(Path(env["DAIMOS_REPO"]) / "system/boot/pdp6"),
           "image", "BOOT_PROFILE=lowmem", "ROOT=disk", "BOOT=dsk",
           "COMPILER=gcc", f"BOOT_CORE_WORDS=0{size*1024:o}",
           f"SIMH_CPU_KWORDS={size}", f"SIMH_DCS0_PORT={port}",
           f"SIMH_GE0_PORT={port+10000}",
           f"DAS_REPO={env.get('DAS_REPO', str(Path.home()/'git/das'))}",
           f"KCC_REPO={env.get('KCC_REPO', str(Path.home()/'git/kcc'))}",
           f"PDP10_PREFIX={env['PDP10_PREFIX']}", f"BUILD_ROOT={work/'build'}"]
    with (work / "build.log").open("wb") as log:
        require(subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT).returncode == 0,
                "disk-root build failed (see build.log)")
    mapping = (boot / "kcore.map").read_text().splitlines()
    wait = [line.split()[1] for line in mapping
            if line.split()[:1] == ["proc_wait_status"]]
    decoder = [line.split()[1] for line in mapping
               if line.split()[:1] == ["d6lz36_decode_core"]]
    require(len(wait) == 1 and decoder == ["000060"],
            "missing WAIT symbol or incorrect D6LZ fixed-address placement")
    ini = (boot / "boot.ini").read_text()
    require(ini.count("go 020") == 1, "unexpected simulator bootstrap script")
    ini = ini.replace("go 020", f"break {wait[0]}\ngo 020\n!sleep 4\n"
                      f"nobreak {wait[0]}\ngo", 1)
    script = work / "carrier-first.ini"
    script.write_text(ini)
    env["SDL_VIDEODRIVER"] = "dummy"
    env["TERM"] = "dumb"
    payload = bytearray()
    logpath = work / "boot.log"
    with logpath.open("wb") as log:
        proc = subprocess.Popen([env.get("SIMH_PDP6", str(Path(env["PDP10_PREFIX"])/"bin/pdp6")),
                                 str(script)], stdout=log, stderr=subprocess.STDOUT,
                                env=env)
        sock = None
        try:
            deadline = time.monotonic() + 50
            while sock is None and time.monotonic() < deadline:
                require(proc.poll() is None, "simulator exited before DCS connection")
                try:
                    sock = socket.create_connection(("127.0.0.1", port), timeout=0.5)
                    sock.settimeout(0.4)
                except OSError:
                    time.sleep(0.1)
            require(sock is not None, "DCS0 carrier did not connect")

            def await_text(target):
                while target not in payload and time.monotonic() < deadline:
                    require(proc.poll() is None, "simulator exited during LOGIN")
                    try:
                        payload.extend(sock.recv(4096))
                    except socket.timeout:
                        pass
                require(target in payload, f"terminal missing {target!r}")

            await_text(b"LOGIN: ")
            print("LOGIN prompt received on DCS0", flush=True)
            sock.sendall(b"ROOT\r")
            await_text(b"DSH V1")
            print("ROOT login entered DSH V1", flush=True)
            await_text(b"# ")
            sock.sendall(b"MEMSTAT\r")
            await_text(b"RESIDENT ")
            print("DSH MEMSTAT executed successfully", flush=True)
        finally:
            if sock is not None:
                sock.close()
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
            (work / "dcs-output.bin").write_bytes(payload)
    bootlog = logpath.read_bytes().replace(b"\r", b"")
    require(b"INIT V1" in bootlog and b"MEMFS" in bootlog and b"D6FS" in bootlog,
            "missing KINIT/INIT/MEMFS/D6FS boot milestones")
    require(b"HALT instruction" not in bootlog and b"?RT" not in bootlog,
            "unexpected kernel halt/root failure")
    print(f"PASS: carrier-first 64-bit-host PDP-6 {size}K DCS0 LOGIN and DSH")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as exc:
        sys.exit(f"FAIL: {exc}")
