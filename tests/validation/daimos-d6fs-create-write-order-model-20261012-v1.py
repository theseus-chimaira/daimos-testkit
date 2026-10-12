#!/usr/bin/env python3
"""Enumerate durable prefixes of D6FS create/dirent publication (testkit only)."""
from dataclasses import dataclass, replace


@dataclass(frozen=True)
class Disk:
    child_fcb: bool = False
    child_data: bool = False
    parent_extent: bool = False
    dirent: bool = False
    parent_size: bool = False
    commit: bool = False


# These are *write boundaries*, not claims of atomic physical sector writes.
STAGES = (
    ('child_fcb', 'child FCB publication'),
    ('child_data', 'optional symlink payload/extent'),
    ('parent_extent', 'optional parent directory growth'),
    ('dirent', 'six-word directory entry'),
    ('parent_size', 'parent FCB metadata/size'),
)


def visible(s: Disk) -> bool:
    # Old-size directory scans cannot see slots beyond the published parent EOF.
    return s.dirent and s.parent_size


def consistent(s: Disk) -> bool:
    return (not visible(s) or (s.child_fcb and s.child_data and
            s.parent_extent)) and (not s.parent_size or s.parent_extent)


def main() -> None:
    print('D6FS create: persistent prefixes (all optional paths enabled)')
    states = [Disk()]
    s = Disk()
    for key, _ in STAGES:
        s = replace(s, **{key: True})
        states.append(s)
    assert len(states) == 6
    for i, state in enumerate(states):
        orphan = state.child_fcb and not visible(state)
        print(f'cut {i}: visible={int(visible(state))} orphan={int(orphan)} '
              f'consistent={int(consistent(state))} '
              f'last={STAGES[i-1][1] if i else "before first write"}')
    # Crash after a successful FCB publication, before the name, is unsafe.
    assert states[1].child_fcb and not visible(states[1])
    # A directory entry written but parent EOF not published may be invisible.
    assert states[4].dirent and not visible(states[4])
    # Once parent EOF is made visible, the child data and FCB must exist.
    assert visible(states[-1]) and consistent(states[-1])
    # A committed bit after all these writes cannot retrospectively prevent
    # earlier crash prefixes from containing unreferenced metadata.
    print('PASS: identifies uncommitted FCB orphan and invisible dirent windows')


if __name__ == '__main__':
    main()
