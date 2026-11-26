#!/usr/bin/env python3
"""Real loss of selected disk during slot-0 swap-in; no guest-state deposits."""
import os
import re
import runpy
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
V = runpy.run_path(str(HERE.parent/'disk-swap-k09-v1955/host-v1955.py'))
H = V['V']
MASK = (1 << 18) - 1
state = {}
operation = os.environ.get("V1956_OPERATION", "read")
assert operation in ("read", "write")
gate = "B" if operation == "read" else "A"


def before_release(token, coremap, examine, read):
    if token != gate:
        return
    b = Path(coremap).parent
    def sym(n):
        return H['source_symbol'](coremap, n)
    prefix = Path(os.environ.get('PDP10_PREFIX', str(Path.home()/'cross')))
    mres = b/'dsk-mres.map'
    patch = read(sym('dsk270_read_call'))
    assert patch >> 18 == 0o322200
    base = (patch & MASK) - H['source_symbol'](mres, 'dsk_read_sector')
    image = dict((int(a,8),int(w,8)) for a,w in re.findall(
        r'(?m)^IMAGE\s+([0-7]+) ([0-7]{12})$',
        subprocess.check_output([str(prefix/'bin/dxrcheck'), '-d',
                                 str(b/'dsk-mres.dxr')],text=True)))
    opcode = 0o727200001105 if operation=='read' else 0o727200002105
    read_pc, = [a for a,w in image.items() if w == opcode]
    # v1959 moves DATAO before descriptor setup; use the exported
    # data symbol when present, keep the old linked-image check.
    if re.search(r'(?m)^dsk_active_request\s+',mres.read_text()):
        active_off = H['source_symbol'](mres, 'dsk_active_request')
    else:
        active_off, = [w & MASK for a,w in image.items()
                       if w >> 18 == 0o202300 and image.get(a+2)==0o727140000001]
    assert read(base+read_pc)==opcode
    # Dedicated fail-stop leaf: CONO PI OFF, CAIE/JRST for root,
    # root HALT/JRST, CAIE/JRST for backing, then backing HALT.
    halt = sym('kcore_critical_device_lost_v1515')+7
    assert read(halt) == (0o254200 << 18) | halt
    state.update(base=base, pc=base+read_pc+1, active=base+active_off,
                 halt=halt)
    examine('break %06o\n'%state['pc'])


def after_release(token, coremap, examine, read, read_range, send, wait, output,
                  fault_boundary=None, after_detach=None):
    if token != gate:
        return False
    def sym(n):
        return H['source_symbol'](coremap,n)
    # A physical breakpoint in the installed MRES, not a user PC.
    wait('Breakpoint, PC: %06o'%state['pc'],0,180)
    wait('sim> ',output.rfind(b'Breakpoint, PC:'),20)
    if fault_boundary is not None:
        fault_boundary(coremap, examine, read, send, wait, output)
    slot=read(sym('proc_current_slot'))
    assert read(sym('storage_state')) == (1<<36)-(3 if operation=='read' else 4)
    assert read(sym('proc_swap_blocks_used'))==(64 if operation=='read' else 0)
    assert read(sym('backstore_blocks_used'))==64
    ptr=read(sym('proc_table'))
    records=read(sym('proc_swap_records'))
    mode=read(sym('proc_storage_runtime_v29'))
    meta=read(ptr+6)
    vm=read(ptr+7)
    record=read(records+2)
    assert meta&0o200000 and vm>>18==8192
    if operation=='read':
        assert slot==0 and vm&MASK==0
        assert (read(mode)>>4)&3==1 and record==64
    else:
        assert slot!=2 and vm&MASK!=0
        assert (read(mode)>>4)&3==0
    active=read(state['active'])
    assert 0 < active>>18 <=300 and active&MASK
    req=active&MASK
    raw=read(req)>>18
    assert read(req+1)==(0 if operation=='read' else 1) and read(req+2)==0
    unit=raw>>16
    assert 0<=unit<4
    print('native swap %s, caller slot %d descriptor %06o raw %06o, detach DSK%d' %
          (operation,slot,req,raw,unit),flush=True)
    # Capture exact destination pin/owner at fault boundary.
    mm=sym('mm_extents')
    count=read(sym('mm_extent_count'))
    start=len(output)
    read_range(mm,2*count,65536)
    d={int(a,8):int(w,8) for a,w in re.findall(
        r'(?m)^(?:sim> )?([0-7]+):\s+([0-7]{12})\s*$',
        output[start:].decode('ascii','ignore'))}
    extent=[(d[mm+2*i],d[mm+2*i+1]) for i in range(count)]
    dest=[(a,m) for a,m in extent if m&0o777777==2 and (m>>18)&7==1]
    assert len(dest)==1 and dest[0][0]>>18==8192 and (dest[0][1]>>21)&255==1
    examine('detach dsk%d\n'%unit)
    if after_detach is not None:
        after_detach(coremap, examine, read, unit, raw)

    examine('nobreak all\n')
    start=len(output)
    send(b'go\n')
    wait('HALT instruction, PC: %06o'%state['halt'],start,180)
    wait('sim> ',start,20)
    assert read(1)==2
    assert read(sym('storage_state'))==0 and read(state['active'])==0
    # Swap-in fails in slot0; swap-out returns to the RUN caller.
    assert read(sym('proc_current_slot'))==(0 if operation=='read' else 1)
    assert read(ptr+6)==meta and read(ptr+7)==vm
    assert (read(mode)>>4)&3==(1 if operation=='read' else 0) and read(records+2)==record
    assert read(sym('proc_swap_blocks_used'))==(64 if operation=='read' else 0)
    assert read(sym('backstore_blocks_used'))==64
    assert read(req+2)==(1<<36)-1
    # The original bitmap must retain the exact run at fail-stop.
    bitmap=read(sym('backstore_bitmap'))
    assert read(bitmap)==(1<<36)-1 and read(bitmap+1)==(1<<28)-1
    # Explicitly repeat the MM examination after HALT. No lost pin,
    # source or destination may be freed or published by the error path.
    assert read(sym('mm_extent_count'))==count
    start=len(output)
    read_range(mm,2*count,65536)
    final={int(a,8):int(w,8) for a,w in re.findall(
        r'(?m)^(?:sim> )?([0-7]+):\s+([0-7]{12})\s*$',
        output[start:].decode('ascii','ignore'))}
    assert final==d
    print('PASS BACKSTORE HALT reason2; exact MM, backing run and transition retained',flush=True)
    return True


if __name__=='__main__':
    H['run'](sys.argv,extra_snapshot=V['extra_snapshot'],
             before_release=before_release,after_release=after_release)
