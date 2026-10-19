#!/usr/bin/env python3
"""Exercise AAP DECtape root, ROOT login, external ECHO and PWD on a PTY.

Usage: daimos-aap-boot-basic-v37.py BUILD EMULATOR DTA2DTR
"""
import os, pty, re, select, subprocess, sys, time
from pathlib import Path
if len(sys.argv) != 4:
    sys.exit("usage: daimos-aap-boot-basic-v37.py BUILD EMULATOR DTA2DTR")
build = Path(sys.argv[1]).resolve()
emulator = Path(sys.argv[2]).resolve()
converter = Path(sys.argv[3]).resolve()
base = Path(os.environ.get('DAIMOS_AAP_WORK_V37',
                           str(Path(os.environ.get('TMPDIR', str(Path.home() / 'tmp'))) /
                               'daimos-aap-boot-basic-v37')))
base.mkdir(parents=True, exist_ok=True)
media = base / 'media'
media.mkdir(exist_ok=True)
for i in range(3):
    raw = media / f'dtc{i}.dta'
    source = build / 'media' / f'dtc{i}.tap'
    raw.write_bytes(source.read_bytes() if source.exists() else b'')
    with open(raw,'r+b') as f: f.truncate(591872)
    subprocess.run([str(converter),str(raw),str(media / f'dx{i}.dtr')],check=True)
master, slave = pty.openpty()
slave_name = os.ttyname(slave)
cmd = [str(emulator)]
log = open(base / 'aap-boot-basic-v37.log','wb', buffering=0)
env = dict(os.environ)
proc = subprocess.Popen(cmd,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,bufsize=0, cwd=base)
os.close(slave)
commands = [f'mount tty {slave_name}',f'mount ptr {build / "stage1-dtc.pt"}',
            f'mount dx0 {media / "dx0.dtr"}', 'mkdev dx1 dx555', 'connectdev dt0 dx1 2',
            f'mount dx1 {media / "dx1.dtr"}', 'switches 02', 'ptrmotor ptr on',
            'power on','deposit 020 0710600000060','deposit 021 0710740000010',
            'deposit 022 0254000000021','deposit 023 0710440000026',
            'deposit 024 0710740000010','deposit 025 0254000000024',
            'deposit 026 000000000000','deposit 027 0254000000021','start 020']
for command in commands:
    proc.stdin.write((command+'\n').encode()); proc.stdin.flush()
    time.sleep(0.08)
print('AAP boot started. CTY PTY:',slave_name,flush=True)
seen = b''
started = time.monotonic()
deadline = started + int(os.environ.get('DAIMOS_AAP_TIMEOUT_V37', '1200'))
login_sent = 0
login_prompt_index = -1
login_attempts = 0
shell_sent = False
pwd_sent = False
while time.monotonic() < deadline:
    for fd in select.select([master,proc.stdout.fileno()],[],[],1)[0]:
        if fd == master:
            try: data=os.read(master,4096)
            except OSError: data=b''
            if data:
                log.write(data)
                seen=(seen+data)[-20000:]
                prompt_idx = seen.rfind(b'LOGIN: ')
                if prompt_idx >= 0 and prompt_idx != login_prompt_index:
                    login_prompt_index = prompt_idx
                    login_attempts += 1
                    login_sent = 0
                if prompt_idx >= 0 and login_attempts == 1 and login_sent == 0:
                    for ch in b'ROOT':
                        os.write(master, bytes([ch]))
                        log.write(b'[HOST_TX_V37] octal=%03o\n' % ch)
                        time.sleep(0.28)
                    login_sent = 4
                if login_sent == 4 and b'LOGIN: ROOT' in seen:
                    time.sleep(0.7)
                    os.write(master, b'\r')
                    log.write(b'[HOST_TX_V37] octal=015 after_full_echo\n')
                    login_sent = 5
                if b'DSH V1' in seen and not shell_sent:
                    print('DSH reached after %.1fs; sending ECHO' % (time.monotonic() - started),flush=True)
                    shell_sent = True
                    for ch in b'ECHO RETESTED_OK_V24\r':
                        os.write(master, bytes([ch]))
                        log.write(b'[HOST_TX_V37_COMMAND] octal=%03o\n' % ch)
                        time.sleep(0.25)
                if shell_sent and not pwd_sent and re.search(rb'(?m)^RETESTED_OK_V24\r?\n# ', seen):
                    print('ECHO PASS after %.1fs; sending PWD' % (time.monotonic() - started),flush=True)
                    pwd_sent = True
                    for ch in b'PWD\r':
                        os.write(master, bytes([ch]))
                        log.write(b'[HOST_TX_V37_PWD] octal=%03o\n' % ch)
                        time.sleep(0.25)
                if pwd_sent and re.search(rb'(?m)^/\r?\n# ', seen):
                    print('PASS: ECHO and PWD completed after %.1fs' % (time.monotonic() - started),flush=True)
                    proc.stdin.write(b'quit\n');proc.stdin.flush()
                    proc.wait(timeout=10)
                    sys.exit(0)
        else:
            data=os.read(proc.stdout.fileno(),4096)
            if data:
                log.write(b'[emulator] '+data)
                if b'APR_STATUS_V1' in data:
                    print(data.decode(errors='replace').strip(),flush=True)
            elif proc.poll() is not None:
                print('AAP exited:',proc.returncode,flush=True)
                sys.exit(1)
    if proc.poll() is not None:
        print('AAP exited before shell:',proc.returncode,flush=True)
        sys.exit(1)
print('TIMEOUT. Last CTY:',repr(seen[-1200:]),flush=True)
proc.stdin.write(b'cpustatus\nquit\n');proc.stdin.flush()
try:proc.wait(timeout=5)
except subprocess.TimeoutExpired:proc.kill()
sys.exit(2)
