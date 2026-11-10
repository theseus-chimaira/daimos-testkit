#!/usr/bin/env python3
"""Build a throwaway EXEC caller using the shared DXR v1386 engine.

This is a source candidate, not a production patch. Guard all extraction
anchors so a future live EXEC change cannot silently invalidate the test.
"""
from pathlib import Path
import sys


def build(source: Path, output: Path) -> None:
    data = source.read_text()
    assert data.count('exec_load_read_header:\n') == 1
    assert data.count('exec_load_create_vm:\n') == 1
    assert data.count('exec_load_image_ok:\n') == 1
    assert data.count('exec_load_plain_image:\n') == 1
    assert 'exec_image_inspect_v1386' not in data
    data = data.replace(
        '        .globl  vm_space_load_file\n', '')
    data = data.replace(
        '        .globl  d6lz36_decode_vfs\n',
        '        .globl  exec_image_inspect_v1386\n'
        '        .globl  exec_image_apply_v1386\n')
    before = data.index('exec_load_read_header:\n')
    after = data.index('exec_load_create_vm:\n', before)
    data = data[:before] + '''exec_load_read_header:
        move    1,12
        move    2,-006(17)             ; validated file size from stat
        movei   3,-010(17)             ; four contiguous parsed DXR words
        pushj   17,exec_image_inspect_v1386
        jumpn   1,exec_load_fail
        hlrz    14,-010(17)           ; entry
        hrrz    13,-010(17)           ; initialized image words
        hlrz    15,-007(17)           ; DXR flags
        hrrz    16,-007(17)           ; BSS words
        trnn    15,0400000            ; RT_REQUIRED
        jrst    exec_load_create_vm
        pushj   17,file_check_root
        jumpn   1,exec_load_fail
        skipn   0,proc_rt_owner
        jrst    exec_load_rt_claim
        came    0,11
        jrst    exec_load_fail
        jrst    exec_load_create_vm
exec_load_rt_claim:
        movem   11,proc_rt_owner
        setom   -012(17)

''' + data[after:]
    before = data.index('        trnn    15,0100000\n',
                        data.index('exec_load_create_vm:\n'))
    after = data.index('exec_load_image_ok:\n', before)
    data = data[:before] + '''exec_load_plain_image:
        move    1,12                   ; immutable vnode
        hrrz    2,1(10)                ; allocated physical VM base
        addi    2,020                  ; image begins at user origin 020
        movei   3,-010(17)            ; parsed DXR descriptor
        setz    4,                    ; FULL mode
        pushj   17,exec_image_apply_v1386
        jumpn   1,exec_load_vm_fail
''' + data[after:]
    assert data.count('        move    4,-007(17)') == 1
    data = data.replace(
        '        move    4,-007(17)              ; validated header_words is 2 or 3',
        '        hrrz    4,-006(17)             ; parsed DXR header size')
    assert data.count('        move    3,-005(17)\n') == 1
    data = data.replace(
        '        move    3,-005(17)\n        pushj   17,proc_swap_attach',
        '        hlrz    3,-006(17)            ; parsed TX2 text words\n'
        '        pushj   17,proc_swap_attach')
    assert 'vm_space_load_file' not in data
    assert 'd6lz36_decode_vfs' not in data
    output.write_text(data)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: make-candidate-v1388.py SOURCE OUTPUT')
    build(Path(sys.argv[1]), Path(sys.argv[2]))
