#!/usr/bin/env python3
"""Bounded real AAP PTR media handoff, driven by stage-one memory state.

The stage_ptr word remains zero until the entire first counted payload is
copied. Never advance to tape 2 merely because a wall-clock delay elapsed.
This diagnostic reports incomplete transfers without claiming kernel boot.
"""
import os
import re
import select
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MEDIA = Path(os.environ.get('AAP_ALT_BOOT_OUT',os.environ.get('TMPDIR',str(Path.home()/'tmp'))+'/aap-alt-stage1-media-v1'))
SOURCES = 'main_net.c emu.c apr.c mem.c tty.c pt.c dc.c dt.c pclk.c netmem.c netcons.c cmd.c util.c threading.c rtc.c ../tools/pdp6common.c'.split()
STAGE_PTR = 0o275  # DAS label stage_ptr=0215 relative to stage1 load base 060
WORD = re.compile(rb'000275: ([0-7]{12})')

def read_until(proc, match, seconds):
    end = time.monotonic()+seconds
    pending=b''
    while time.monotonic()<end:
        ready,_,_=select.select([proc.stdout],[],[],min(0.5,max(0,end-time.monotonic())))
        if ready:
            chunk=os.read(proc.stdout.fileno(),4096)
            if not chunk:raise RuntimeError('console closed')
            pending+=chunk
            if match.search(pending):return pending
            if len(pending)>65536:pending=pending[-16384:]
    raise TimeoutError('no stage-one memory readback')

with tempfile.TemporaryDirectory(prefix='aap-ptr-handoff-v1.',dir=os.environ.get('TMPDIR',str(Path.home()/'tmp'))) as d:
    w=Path(d)
    emulator=w/'pdp6_n'
    # Diagnostic-only copy: do not alter the emulator repository.
    source=(ROOT.parent/'pdp6/emu/pt.c').read_text()
    source=source.replace('n = read(ptr->fd, &c, 1);', '''n = read(ptr->fd, &c, 1);
    if(n == 1){ static unsigned samples; if((samples++ < 16) || (ptr->fd >= 0 && lseek(ptr->fd,0,SEEK_CUR) <= 5))
        fprintf(stderr,"PTR_RAW_V1 sample=%u offset=%ld octet=%03o\\n",samples,(long)lseek(ptr->fd,0,SEEK_CUR),c); }''')
    source=source.replace('bus->c12 |= ptr->ptr;', '''{ static unsigned samples; if((samples++ < 16) || (ptr->fd >= 0 && lseek(ptr->fd,0,SEEK_CUR) <= 5))
                fprintf(stderr,"PTR_DATAI_V1 sample=%u offset=%ld data=%012lo flag=%d busy=%d\\n",samples,(long)(ptr->fd >= 0 ? lseek(ptr->fd,0,SEEK_CUR) : -1),ptr->ptr,ptr->flag,ptr->busy);
            bus->c12 |= ptr->ptr; }''')
    (w/'ptr-diag-v1.c').write_text(source)
    subprocess.run([os.environ.get('CC','cc'),'-O2','-I',str(ROOT.parent/'pdp6/emu'),'-o',str(emulator),*[(str(w/'ptr-diag-v1.c') if name=='pt.c' else name) for name in SOURCES],'-lpthread','-lm'],cwd=ROOT.parent/'pdp6/emu',check=True)
    (w/'init.ini').write_text('mkdev apr apr166\nmkdev ptr ptr760 1\nmkdev fmem fmem162 0\nmkdev mem0 moby mem_0\nconnectio ptr apr\nconnectmem fmem 0 apr -1\nconnectmem mem0 0 apr 0\nmount ptr %s\n'% Path(os.environ.get('AAP_PTR_STAGE1_TAPE',str(MEDIA/'stage1-ptr-no-trailer-v2.pt'))))
    commands=['power on','deposit 20 710600000060','deposit 21 710740000010','deposit 22 254000000021','deposit 23 710440000026','deposit 24 710740000010','deposit 25 254000000024','deposit 26 000000000000','deposit 27 254000000021','ptrmotor ptr on','start 20']
    trace_file = (w/'stage1-aap-v1.trace').open('w+b')
    env=dict(os.environ,PDP6_AAP_TIMING_TRACE_V1='1',PDP6_AAP_CLASS_TRACE_V1='1')
    with subprocess.Popen([str(emulator)],cwd=w,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=trace_file,env=env,bufsize=0) as proc:
        def send(line):
            proc.stdin.write((line+'\n').encode());proc.stdin.flush()
        for command in commands:send(command)
        # Advance only after a genuine AAP instruction-start at the
        # Stage-1 entry, not a wall-clock delay or an unverified marker.
        deadline=time.monotonic()+8
        ready=False
        while time.monotonic()<deadline:
            trace_file.flush()
            text=(w/'stage1-aap-v1.trace').read_text(errors='replace')
            if text.count('pc=000146 ') >= 10:
                ready=True
                break
            time.sleep(0.05)
        assert ready, 'AAP trace did not confirm Stage-1 entry; refuse tape swap'
        print('Stage-1 first-byte wait observed repeatedly at PC 000146')
        send('unmount ptr');send('mount ptr %s'%(MEDIA/'ptr-boot1-v1.pt'))
        # Linux/Termux exposes the real mounted reader's consumed byte
        # count in /proc/PID/fdinfo. This is read-only instrumentation.
        def reader_offset():
            fdroot=Path('/proc')/str(proc.pid)/'fd'
            try:
                for fd in fdroot.iterdir():
                    try:
                        target=os.readlink(fd)
                        if target.endswith('ptr-boot1-v1.pt'):
                            info=(fdroot.parent/'fdinfo'/fd.name).read_text()
                            match=re.search(r'^pos:\s*(\d+)', info, re.M)
                            return int(match.group(1)) if match else None
                    except (OSError, ValueError):
                        continue
            except (OSError, PermissionError):
                pass
            return None
        def wait_trace_pc(pc, seconds):
            # Follow only newly appended execution records; the trace can
            # contain millions of events while decoding the KINIT payload.
            token=('pc=%06o ' % pc).encode('ascii')
            deadline=time.monotonic()+seconds
            cursor=0
            tail=b''
            path=w/'stage1-aap-v1.trace'
            while time.monotonic()<deadline:
                with path.open('rb') as reader:
                    reader.seek(cursor)
                    chunk=reader.read()
                cursor+=len(chunk)
                if token in tail+chunk:
                    return True
                tail=(tail+chunk)[-64:]
                time.sleep(0.075)
            return False

        # Relocated Stage-1 PC 000117 writes the nonzero stage_ptr, then
        # PC 000123 invokes read_word for tape 2 after resetting the PTR.
        first_complete=wait_trace_pc(0o123,55)
        maximum_offset=reader_offset()
        print('PTR payload1 consumed bytes (last observed): %s / %d' %
              (str(maximum_offset) if maximum_offset is not None else 'unavailable',
               (MEDIA/'ptr-boot1-v1.pt').stat().st_size))
        if first_complete:
            send('unmount ptr')
            send('mount ptr %s' % (MEDIA/'ptr-boot2-v1.pt'))
            print('PTR first payload completed; Stage-1 PC 000123 observed; mounted tape 2')
            if wait_trace_pc(0o252,60):
                print('PTR second payload Stage-1 handoff reached PC 000252')
                header=(ROOT.parent/'DAIMOS/build/system/boot/pdp6/kinit.d6lz.words').read_text().splitlines()[1]
                kinit_entry=0o30000+(int(header,8)&0o777777)
                if wait_trace_pc(kinit_entry,45):
                    print('LINKED KINIT ENTRY OBSERVED at PC %06o' % kinit_entry)
                    time.sleep(1.5)
                else:
                    print('KINIT entry PC %06o NOT OBSERVED after decoder handoff' % kinit_entry)
            else:
                print('PTR second payload handoff NOT OBSERVED in bounded interval')
        else:
            print('PTR first payload completion NOT OBSERVED; tape 2 not mounted')
        from collections import Counter
        pcs=Counter(re.findall(r'AAP_TIMING_V1 IT0 tick=\d+ pc=([0-7]{6})', (w/'stage1-aap-v1.trace').read_text(errors='replace')))
        print('AAP top executed PCs:',pcs.most_common(15))
        print('Device trace:',re.findall(r'PTR_(?:RAW|DATAI)_V1[^\n]*',(w/'stage1-aap-v1.trace').read_text(errors='replace'))[-25:])
        events=re.findall(r'AAP_TIMING_V1 IT0 tick=\d+ pc=([0-7]{6}) inst=([0-7]{3})',(w/'stage1-aap-v1.trace').read_text(errors='replace'))
        print('Final PCs:',events[-22:])
        classes=re.findall(r'AAP_CLASS_EVENT_V1 type=([A-Z_]+) ',(w/'stage1-aap-v1.trace').read_text(errors='replace'))
        print('AAP CLASS EVENTS:',Counter(classes))
        print('AAP EXCEPTION EVENT DETAILS:',re.findall(r'AAP_CLASS_EVENT_V1 type=(?:NXM|ILLOP|PDLOV|PI_CYCLE) tick=[0-9]+ pc=[0-7]{6}',(w/'stage1-aap-v1.trace').read_text(errors='replace'))[:24])
        from collections import deque
        before=deque(maxlen=15)
        with (w/'stage1-aap-v1.trace').open(errors='replace') as lines:
            for line in lines:
                if line.startswith('AAP_CLASS_EVENT_V1 type=PDLOV '):
                    print('PDLOV INSTRUCTION CONTEXT:',line.strip(),list(before))
                if line.startswith('AAP_TIMING_V1 '):
                    before.append(line.strip())
        print('KINIT ENTRY TIMING:',re.findall(r'AAP_TIMING_V1 IT0 tick=([0-9]+) pc=054074', (w/'stage1-aap-v1.trace').read_text(errors='replace'))[:2])
        try:
            entry_at=next(i for i,event in enumerate(events) if event[0]=='054074')
        except StopIteration:
            print('KINIT post-entry trace: no entry')
        else:
            from collections import Counter
            post=events[entry_at:]
            hits=Counter(pc for pc,opcode in post)
            print('KINIT post-entry samples:',len(post),'distinct PCs:',len(hits))
            print('KINIT first PCs:',post[:35])
            print('KINIT hot PCs:',hits.most_common(20))
            low={pc:n for pc,n in hits.items() if 0o1000<=int(pc,8)<0o30000}
            print('POST-ENTRY LOWCORE KCORE CANDIDATES:',sum(low.values()),len(low),sorted(low.items(),key=lambda x:-x[1])[:15])
            for label,address in [('mres_init','053244'),('module_run_minits','053731'),('mres_install','053254'),('kinit_halt','070422')]:
                print('KINIT SYMBOL HIT',label,address,hits[address])
            print('Last after KINIT:',post[-25:])
        send('cpustatus')
        try:
            status=read_until(proc,re.compile(rb'APR_STATUS_V1 (?:HALTED|RUNNING|START_PENDING)'),1)
            print('CPU status:',re.findall(rb'APR_STATUS_V1 [A-Z_]+',status)[-1:])
        except TimeoutError: print('CPU status: unresponsive')
        for address in ('2','3','5','17','100','274','275','276','22674','22675','23771','24000','54074'):
            send('examine '+address)
        send('xexamine apr.pc')
        send('quit')
        try:
            output,_=proc.communicate(timeout=2)
            readbacks=re.findall(rb'([0-7]{6}): ([0-7]{12})',output)
            print('Post-halt readbacks:',readbacks[-14:])
            print('Post-halt console tail:',output[-360:])
            values={int(a,8):int(v,8) for a,v in readbacks}
            linked=(ROOT.parent/'DAIMOS/build/system/boot/pdp6/kinit.words').read_text().splitlines()
            for address,source in ((0o54074,0o54074),(0o22674,0o30030+(0o22674-0o60)),(0o22675,0o30030+(0o22675-0o60))):
                expected=int(linked[2+source-0o30000],8)
                observed=values.get(address)
                print('IMAGE PROVENANCE %06o expected=%012o observed=%s match=%s'%(address,expected,('%012o'%observed if observed is not None else 'MISSING'),observed==expected))
            for address in (0o23771,0o24000):
                print('MRES RUNTIME WORD %06o = %s'%(address,('%012o'%values[address]) if address in values else 'MISSING'))
            import importlib.util
            spec=importlib.util.spec_from_file_location('linked_profile',ROOT/'tools/aap-linked-runtime-profile-v2.py')
            linked_profile=importlib.util.module_from_spec(spec)
            spec.loader.exec_module(linked_profile)
            report=linked_profile.profile(w/'stage1-aap-v1.trace',
                    ROOT.parent/'DAIMOS/build/system/boot/pdp6/kinit.words',
                    ROOT.parent/'DAIMOS/build/system/boot/pdp6/kinit.map',values)
            import json
            report_file=Path(os.environ.get('TMPDIR',str(Path.home()/'tmp')))/'aap-linked-runtime-profile-v2.json'
            report_file.write_text(json.dumps(report,indent=2)+'\n')
            print('LINKED PROFILE VERIFIED:',report['region_starts'],'events:',report['exception_events'])
            print('LINKED PROFILE REPORT:',report_file)

        except subprocess.TimeoutExpired:proc.kill();proc.communicate()
trace_file.close()
print('Complete DAIMOS boot and exception-free linked timing NOT VERIFIED')
