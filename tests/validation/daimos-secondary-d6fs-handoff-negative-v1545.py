#!/usr/bin/env python3
"""Reject corrupt physical D6FS handoffs without changing real media."""
from pathlib import Path
import importlib.util
import sys


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: TESTKIT_DIR MEDIA_DIR')
    tests = Path(sys.argv[1])
    media = Path(sys.argv[2])
    module_path = tests / 'daimos-secondary-d6fs-media-handoff-v1545.py'
    spec = importlib.util.spec_from_file_location('d6fs_handoff_v1545', module_path)
    tool = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tool)

    original = tool.physical_block
    members = tool.descriptors(media)
    assert len(members) == 4
    assert len(tool.handoff(members,'dsk')) == 14
    assert len(tool.handoff(members,'drm')) == 14
    layout = []
    for unit in range(4):
        found = [i for i in range(0o200) if
                 original(media / ('dsk%d.dsk' % unit),i)[0o6] ==
                 tool.LAYOUT_MAGIC]
        assert len(found) == 1
        layout.append(found[0])

    def one_mutation(name, action):
        def altered(path, phys):
            content = original(path,phys)
            result = action(path,phys,content)
            return result
        tool.physical_block = altered
        try:
            mutant_members = tool.descriptors(media)
            tool.handoff(mutant_members,'dsk')
        except ValueError:
            print('PASS v1545: rejected invalid physical handoff ' + name)
        else:
            raise AssertionError('accepted corrupted physical D6FS ' + name)
        finally:
            tool.physical_block = original

    def corrupt_layout(path,sector,block):
        if path.name == 'dsk2.dsk' and sector == layout[2]:
            block[0o7] += 1
        return block

    def missing_descriptor(path,sector,block):
        if path.name == 'dsk1.dsk' and sector == layout[1]:
            block[0o6] = 0
        return block

    def corrupt_super(path,sector,block,logical,word,newvalue):
        unit = logical % 4
        local = members[unit][1] + logical // 4
        if path.name == 'dsk%d.dsk' % unit and sector == local:
            block[word] = newvalue
        return block

    sa, sb = members[0][3:5]
    one_mutation('missing-DBOOT',missing_descriptor)
    one_mutation('inconsistent-member-range',corrupt_layout)
    one_mutation('superblock-mismatch',lambda p,s,w:
                 corrupt_super(p,s,w,sa,0o1,w[0o1]+1))
    one_mutation('unclean-superblock',lambda p,s,w:
                 corrupt_super(p,s,w,sb,0o2,1))
    one_mutation('invalid-total',lambda p,s,w:
                 corrupt_super(p,s,w,sa,0o7,w[0o7]+1))
    one_mutation('invalid-root-FCB',lambda p,s,w:
                 corrupt_super(p,s,w,sb,0o10,w[0o12]+1))
    print('PASS v1545: six corrupted physical handoff oracles rejected')


if __name__ == '__main__':
    main()
