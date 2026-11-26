#!/usr/bin/env python3
"""Native PDP-6 source loss and replacement; never deposit kernel memory."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import runpy
import select
import shutil
import subprocess
import time

HERE = Path(__file__).resolve().parent
old = runpy.run_path(str(HERE.parent / 'pure-k07-full-v1941/replay-v1941.py'))
check = runpy.run_path(str(HERE.parent / 'pure-k07-full-v1941/verify-v1941.py'))
symbols, words = old['symbols'], old['words']
extents = check['extents']
MASK = 0o777777
NEG4 = 0o777777777774
NAMES = ('proc_current_slot', 'proc_high_slot', 'proc_sched_cursor',
         'proc_table', 'proc_swap_records', 'dtfs_media_base',
         'vfs_mount_root_base', 'vfs_namespace_root', 'tsfs_file_shape_base',
         'tsfs_extent_media_base', 'proc_exec_resv_head_v1933',
         'proc_timer_clock', 'mm_extent_count', 'mm_extent_capacity',
         'mm_arena_count', 'proc_swap_service_one', 'proc_swap_reclaim')


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main(observer=None):
    """Optional testkit observer extends the original physical replay."""
    p = argparse.ArgumentParser()
    for n in ('build', 'work', 'prefix'):
        p.add_argument(n, type=Path)
    p.add_argument('--timeout', type=int, default=1150)
    a = p.parse_args()
    b, w, prefix = (x.resolve() for x in (a.build, a.work, a.prefix))
    w.mkdir(parents=True, exist_ok=True)
    media = w / 'media'
    media.mkdir()
    s = symbols(b / 'kcore.map')
    m = symbols(b / 'pure-mres-v1612.map')
    image = subprocess.check_output([str(prefix / 'bin/dxrcheck'), '-d',
                                     str(b / 'pure-mres-v1612.dxr')], text=True)
    instructions = {int(x, 8): int(y, 8) for x, y in re.findall(
        r'(?m)^IMAGE\s+([0-7]{6}) ([0-7]{12})$', image)}
    service = m['proc_pure_mres_service_v1612']
    full = m['exec_image_full_bounded_v1391']
    def return_offset(name):
        hits = [i+1 for i, v in instructions.items()
                if service <= i < service + 0o400 and
                v == (0o260740000000 | m[name])]
        assert len(hits) == 1, name
        return hits[0]
    pr = return_offset('proc_pure_restore_v1384')
    fr = return_offset('proc_pure_ram_restore_v1391')
    lines = []
    for line in (b / 'boot.ini').read_text().splitlines():
        f = line.split()
        if line.startswith('attach -q '):
            dev = f[2]
            if dev.startswith(('dsk', 'dr')):
                continue
            if dev.startswith(('dtc', 'mtc')):
                dst = media / (dev + '.tap')
                shutil.copyfile(f[3], dst)
                line = 'attach -q ' + dev + ' ' + str(dst)
        if line.startswith('attach -q -n '):
            line = 'attach -q -n ' + f[3] + ' ' + str(media / (f[3]+'.out'))
        if line.startswith('set -q -n log '):
            line = 'set -q -n log ' + str(w / 'simh.log')
        lines.append(line)
    original = media / 'dtc3.tap'
    foreign = media / 'foreign.tap'
    shutil.copyfile(b / 'media/foreign-v1945.tap', foreign)
    orig_hash, foreign_hash = digest(original), digest(foreign)
    assert original.read_bytes()[:24] != foreign.read_bytes()[:24]
    (w / 'images.sha256').write_text(''.join(
        digest(b / n) + '  ' + n + '\n' for n in
        ('kcore.dxr', 'kinit.lowmem.words', 'pure-mres-v1612.dxr')))
    (w / 'media.sha256').write_text(orig_hash+'  dtc3.tap\n'+foreign_hash+'  foreign.tap\n')
    ini = '\n'.join(lines)+'\n'
    assert ini.count('go 020\nexit\n') == 1 and 'set pclk REALTIME' in ini
    def scalar(label, namespace='V1945'):
        names = NAMES if observer is None else NAMES + observer.names
        return ('echo '+namespace+'_STAGE_'+label+'\n' +
                ''.join('examine %06o\n' % s[n] for n in names) +
                'examine 1-4\necho '+namespace+'_SCALAR_'+label+'\n')
    initial = 'expect "x[B"\n'
    if observer is not None:
        initial += 'expect "!r"\nexpect "!u"\n'
    ini = ini.replace('go 020\nexit\n', initial+'go 020\n'+scalar('B'))
    (w / 'physical.ini').write_text(ini)
    port = 37000 + os.getpid() % 9000
    subprocess.run(['sh', str(HERE.parents[1] / 'lib/daimos-simh-headless.sh'),
                    str(w / 'physical.ini'), str(w / 'headless.ini'),
                    str(port), str(port+12000)], check=True)
    proc = subprocess.Popen(['stdbuf','-o0','-e0',str(prefix / 'bin/pdp6'),
                             str(w / 'headless.ini')], cwd=b, stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            env=dict(os.environ, TERM='dumb'), bufsize=0)
    deadline = time.monotonic()+a.timeout
    buf = bytearray()
    source = None
    with (w / 'physical.log').open('wb', buffering=0) as log:
        def wait(marker, start):
            while marker.encode() not in buf[start:]:
                if time.monotonic() >= deadline:
                    raise RuntimeError('timeout before '+marker)
                if not select.select([proc.stdout], [], [], .5)[0]:
                    continue
                chunk = os.read(proc.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError('simulator exited before '+marker)
                buf.extend(chunk); log.write(chunk)
                if len(buf) > 8000000:
                    raise RuntimeError('oversized physical transcript')
            return buf[start:].decode('ascii', 'replace').replace('\r', '')
        def send(cmd):
            start = len(buf)
            proc.stdin.write(cmd.encode('ascii')); proc.stdin.flush()
            return start
        def examine(addr, length):
            assert 0 < addr < 0o140000 and 0 < length <= 0o140000-addr
            return 'examine %06o-%06o\n' % (addr, addr+length-1)
        def capture(label, start, suffix=False, namespace='V1945'):
            t = wait(namespace+'_SCALAR_'+label, start)
            d = words(t.split(namespace+'_STAGE_'+label+'\n',1)[1])
            high, count = d[s['proc_high_slot']], d[s['mm_extent_count']]
            assert 1 < high <= 24 and 0 < count <= d[s['mm_extent_capacity']] <= 136
            table = d[s['proc_table']]
            cmd = examine(table, high*3)+examine(d[s['proc_swap_records']],high)
            for n in ('dtfs_media_base','vfs_mount_root_base','tsfs_file_shape_base','tsfs_extent_media_base'):
                cmd += examine(d[s[n]],2)
            cmd += examine(s['mm_extents'],2*count)+examine(s['mm_arenas'],d[s['mm_arena_count']])
            if observer is not None:
                cmd += examine(d[s['proc_storage_runtime_v29']],1)
            start2 = send(cmd+'echo '+namespace+'_TABLES_'+label+'\n')
            t2 = wait(namespace+'_TABLES_'+label, start2)
            d.update(words(t2))
            e = extents(d,s)
            u = d[table+9] >> 18 if high > 3 else 0
            if u and any(q[0] == u and q[2] == 3 and q[4] == 0o1003 for q in e):
                cmd = examine(u+0o66,2)+examine(u+0o406,1)
            else:
                cmd = ''
            if suffix:
                assert source is not None
                cmd += examine(source[0],source[1]-source[0])
            start3 = send(cmd+'echo '+namespace+'_END_'+label+'\n')
            d.update(words(wait(namespace+'_END_'+label,start3)))
            print(namespace.lower(), label, 'slot', d[s['proc_current_slot']], 'cursor', d[s['proc_sched_cursor']], 'MM',count,flush=True)
            return t,d,e
        try:
            t,d,e = capture('B',0)
            match = re.search(r'I(a{4,6})x\[BV1945_STAGE_B\n',t)
            assert match, 'actual guest admission marker missing: '+t.split('V1945_STAGE_B',1)[0][-100:]
            children = len(match.group(1))
            source = next(q for q in e if q[2] == 4 and q[4] == 3 and q[3] == 0)
            base = (d[s['proc_swap_service_one']] & MASK)-service
            assert d[s['proc_swap_service_one']] >> 18 == 0o254000
            assert d[s['proc_swap_reclaim']] == 0o254000000000 | (base+m['proc_pure_mres_reclaim_v1612'])
            full += base; pr += base; fr += base
            print('v1945 actual FULL %06o prefix-return %06o full-return %06o' % (full,pr,fr),flush=True)
            _,d2,e2 = capture('A',send('expect "[A"\ncont\n'+scalar('A')))
            assert e2 == e
            start = send('examine %06o\necho V1945_OPCODE\n' % full)
            assert words(wait('V1945_OPCODE',start))[full] == instructions[full-base]
            t,d,e = capture('FULL',send('break %06o\ncont\n' % full+scalar('FULL')),True)
            assert re.search(r'Breakpoint, PC: %06o\b' % full,t)
            assert d[s['proc_sched_cursor']] == 3 and d[s['proc_current_slot']] == 0
            assert d[1] >> 18 & 15 == 1
            assert (source[0],source[1],4,1,3) in e
            dst = next(q for q in e if q[2] == 1 and q[4] == 3 and q[3] == 1)
            assert dst[0] == d[2] and dst[1]-dst[0] == d[4]
            expected = tuple(d[i] for i in range(source[0],source[1]))
            def observe(stage, **extra):
                if observer is None:
                    return
                observer(stage, sym=s, mres=m, base=base, full=full,
                         pr=pr, fr=fr, source=source, target=dst,
                         suffix=expected, send=send, wait=wait,
                         scalar=scalar, capture=capture, **extra)
            observe('FULL', snapshot=d, owners=e)
            def refused(label, command, pc):
                t,d,e = capture(label,send(command+scalar(label)),True)
                assert re.search(r'Breakpoint, PC: %06o\b' % pc,t)
                assert d[s['proc_current_slot']] == 0 and d[s['proc_sched_cursor']] == 3
                assert d[1] == NEG4, 'restore did not return typed invalid'
                assert [q for q in e if q[4] == 3 and q[2] in (1,4)] == [source]
                assert tuple(d[i] for i in range(source[0],source[1])) == expected
                assert d[d[s['dtfs_media_base']]+1] & 0o200000
                return d
            guard = '' if observer is None else 'break %06o\n' % s['proc_sched_restore_selected']
            failed = refused('MISSING','nobreak all\ndetach dtc3\nshow dtc3\nbreak %06o\n'%fr+guard+'cont\n',fr)
            observe('MISSING', snapshot=failed)
            # A retry can take PREFIX or FULL depending on the free gap.
            # Stop at both actual transaction returns; fallback (+1) is
            # not a source rejection, and must be followed to FULL.
            command = ('nobreak all\nattach -q dtc3 '+str(foreign)+'\nshow dtc3\n'
                       'break %06o\nbreak %06o\ncont\n' % (pr,fr))
            for i in range(16):
                label = 'FOREIGN_%d' % i
                t,d,e = capture(label,send(command+scalar(label)),True)
                hit = re.search(r'Breakpoint, PC: ([0-7]{6})\b',t)
                assert hit and int(hit.group(1),8) in (pr,fr)
                if d[s['proc_sched_cursor']] == 3 and d[1] != 1:
                    assert d[1] == NEG4 and d[s['proc_current_slot']] == 0
                    assert [q for q in e if q[4] == 3 and q[2] in (1,4)] == [source]
                    assert tuple(d[j] for j in range(source[0],source[1])) == expected
                    assert d[d[s['dtfs_media_base']]+1] & 0o200000
                    break
                command = 'cont\n'
            else:
                raise AssertionError('no actual foreign-source refusal')
            reattach = 'nobreak all\ndetach dtc3\nattach -q dtc3 '+str(original)+'\nshow dtc3\n'
            if observer is not None:
                observe('RECOVER', snapshot=d, reattach=reattach)
                reattach = 'nobreak all\n'
            t,d,e = capture('Z',send(reattach+'expect "Z"\ncont\n'+scalar('Z')))
            assert t.split('V1945_STAGE_Z\n')[0].endswith('Z')
            assert not any(q[2] in (1,4) and q[4]>=2 or q[2]==3 and q[4]>=0o1002 for q in e)
            assert not d[d[s['vfs_mount_root_base']]+1]
            assert not d[s['proc_exec_resv_head_v1933']]
            start = send('cont\nexit\n')
            wait('HALT instruction, PC: 000000',start); wait('Goodbye',start)
            assert proc.wait(timeout=10)==0
            assert digest(original)==orig_hash and digest(foreign)==foreign_hash
            print('PASS v1945: actual source loss, foreign refusal, same reel recovery and %d exact WAITs' % children,flush=True)
        finally:
            if proc.poll() is None:
                proc.terminate()
                try: proc.wait(timeout=5)
                except subprocess.TimeoutExpired: proc.kill(); proc.wait()
            while select.select([proc.stdout],[],[],0)[0]:
                data=os.read(proc.stdout.fileno(),65536)
                if not data: break
                buf.extend(data);log.write(data)
            (w/'physical.clean').write_bytes(bytes(buf).replace(b'\r',b''))

if __name__ == '__main__':
    main()
