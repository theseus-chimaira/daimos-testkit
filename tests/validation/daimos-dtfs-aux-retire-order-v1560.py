#!/usr/bin/env python3
"""Verify v1560 retained MM ownership is checked before slot retirement.

This is a source-ordering regression, complementing the actual PDP-6
mount/unmount native tests. It does not simulate a physical tape transfer.
"""

import argparse
from pathlib import Path


def check(repo):
    fs = repo / 'system' / 'kernel' / 'fs'
    vfs = (fs / 'vfs.s').read_text()
    mres = (fs / 'fs_mres.s').read_text()
    assert mres.count('d6fs_reader_slots_base:\n'
                      'vfs_mount_aux_base_v1560:\n') == 1, (
        'auxiliary MM slot must alias D6FS reader storage exactly')

    def section(start, end):
        assert vfs.count(start) == 1 and vfs.count(end) == 1
        return vfs[vfs.index(start):vfs.index(end, vfs.index(start))]

    mount = section('vfs_mount_found:\n',
                    '; Publish one validated slot')
    unmount = section('vfs_unmount_after_prepare:\n',
                      '; Retire exactly one unmounted slot')
    discard = section('vfs_dtfs_discard_slot_v1531:\n',
                      'vfs_dtfs_discard_bad_v1531:')
    discard_io=discard.index('pushj   17,fs_provider_reg_call')
    discard_pre=discard[:discard_io]
    discard_post=discard[discard_io:]

    def before(label, source, anchors):
        positions=[]
        for anchor in anchors:
            assert source.count(anchor) == 1, (label,anchor,source.count(anchor))
            positions.append(source.index(anchor))
        assert positions == sorted(positions), label

    before('mount must refuse before publication', mount, (
        'caie    2,5                     ; DTFS_PROVIDER',
        'pushj   17,vfs_dtfs_aux_empty_v1560',
        'jumpn   6,kret_neg1',
        'pushj   17,vfs_mount_publish_slot',
    ))
    before('unmount must recheck after sleeping calls', unmount, (
        'pushj   17,vfs_unmount_owner_check_v1523',
        'pushj   17,vfs_dtfs_aux_empty_v1560',
        'jumpn   1,vfs_unmount_fail\nvfs_unmount_aux_done_v1560:',
        'pushj   17,file_unlock_mount',
        'pushj   17,vfs_mount_retire_slot',
    ))
    before('admin discard must refuse MM owner before raw I/O', discard_pre, (
        'pushj   17,vfs_unmount_owner_check_v1523',
        'pushj   17,vfs_dtfs_aux_empty_v1560',
        'jumpn   1,vfs_dtfs_discard_bad_v1531\n'
        '        move    1,010                   ; zero-based slot',
    ))
    before('admin discard must retain MM owner after raw I/O', discard_post, (
        'pushj   17,fs_provider_reg_call',
        'pushj   17,vfs_dtfs_aux_empty_v1560',
        'jumpn   1,vfs_dtfs_discard_bad_v1531\n'
        '        movei   1,1(010)\n'
        '        pushj   17,file_unlock_mount',
        'pushj   17,file_unlock_mount',
        'pushj   17,vfs_mount_retire_slot',
    ))
    assert vfs.count('vfs_dtfs_aux_empty_v1560:\n') == 1
    print('PASS v1560: mount/unmount/admin-discard owner-before-retire ordering')


def test_mutants(repo):
    import shutil
    import tempfile

    with tempfile.TemporaryDirectory(prefix='daimos-v1560-retire-') as work:
        fs = Path(work) / 'system' / 'kernel' / 'fs'
        fs.mkdir(parents=True)
        for filename in ('vfs.s','fs_mres.s'):
            shutil.copyfile(repo/'system'/'kernel'/'fs'/filename,fs/filename)
        mutants=(
            ('drop-mount-refusal','vfs.s',
             'jumpn   6,kret_neg1\nvfs_mount_aux_checked_v1560:',
             'jumpe   6,kret_neg1\nvfs_mount_aux_checked_v1560:'),
            ('drop-unmount-refusal','vfs.s',
             'jumpn   1,vfs_unmount_fail\nvfs_unmount_aux_done_v1560:',
             'jumpe   1,vfs_unmount_fail\nvfs_unmount_aux_done_v1560:'),
            ('drop-admin-early-check','vfs.s',
             'pushj   17,vfs_dtfs_aux_empty_v1560\n'
             '        jumpn   1,vfs_dtfs_discard_bad_v1531\n'
             '        move    1,010                   ; zero-based slot',
             'setz    1, ; incorrectly start raw I/O with owned scratch\n'
             '        jumpn   1,vfs_dtfs_discard_bad_v1531\n'
             '        move    1,010                   ; zero-based slot'),
            ('drop-admin-final-check','vfs.s',
             'pushj   17,vfs_dtfs_aux_empty_v1560\n'
             '        jumpn   1,vfs_dtfs_discard_bad_v1531\n'
             '        movei   1,1(010)\n'
             '        pushj   17,file_unlock_mount',
             'setz    1, ; incorrectly abandon scratch owner\n'
             '        jumpn   1,vfs_dtfs_discard_bad_v1531\n'
             '        movei   1,1(010)\n'
             '        pushj   17,file_unlock_mount'),
            ('split-shared-pointer','fs_mres.s',
             'd6fs_reader_slots_base:\nvfs_mount_aux_base_v1560:',
             'd6fs_reader_slots_base:\n        .word 0\n'
             'vfs_mount_aux_base_v1560:'),
        )
        for label,filename,before,after in mutants:
            path=fs/filename
            original=path.read_text()
            assert original.count(before)==1,(label,original.count(before))
            path.write_text(original.replace(before,after,1))
            try:
                check(Path(work))
            except AssertionError:
                print('PASS v1560: rejected '+label)
            else:
                raise AssertionError('unsafe mutation accepted: '+label)
            path.write_text(original)
        return len(mutants)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('repo',type=Path)
    args=parser.parse_args()
    check(args.repo)
    count=test_mutants(args.repo)
    print('PASS v1560: %d unsafe source-order mutations rejected' % count)


if __name__=='__main__':
    main()
