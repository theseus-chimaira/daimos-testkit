#!/usr/bin/env python3
"""Create a full-system v1724 dual-refusal guest from the v1723 witness.

All fault hooks affect disposable copied kernel sources. The production
VM, PIPE, FILE, VFS and RUN implementations are left intact otherwise.
"""

from pathlib import Path
import sys


def once(text, before, after):
    count = text.count(before)
    if count != 1:
        raise SystemExit("v1724: source anchor count %d for %r" %
                         (count, before[:110]))
    return text.replace(before, after, 1)


def main():
    if len(sys.argv) != 5:
        raise SystemExit("usage: generator V1723_SH V1723_C OUTDIR TESTDIR")
    script_path, user_path = Path(sys.argv[1]), Path(sys.argv[2])
    work = Path(sys.argv[3])
    selfdir = Path(sys.argv[4]).resolve()

    guest_c = user_path.read_text()
    guest_c = once(guest_c,
        '#include "../test_sixbit.h"',
        '#include "%s"' % (selfdir.parent / 'test_sixbit.h'))
    guest_c = once(guest_c,
        '#define MAP_COUNT       6U',
        '#define MAP_COUNT       7U')
    guest_c = once(guest_c,
        'static kword_t init_path[] = {',
        '''static kword_t regular_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static kword_t init_path[] = {''')
    guest_c = once(guest_c,
        'spawn_child(int rd, int wr, int control_rd)',
        'spawn_child(int rd, int wr, int control_rd, int regular_fd)')
    guest_c = once(guest_c,
        '        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,',
        '''        block[MAP_OFF + 6U] = SYS_RUN_FD_MAP(6U,
            (unsigned int)regular_fd);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,''')
    guest_c = once(guest_c,
        '        int child;',
        '        int child;\n        int regular_fd;\n'
        '        struct sys_meminfo child_state;')
    guest_c = once(guest_c,
        '''                /* First EXIT closed all successful entries, but retained
                 * the final PIPE FD after MM_BUSY. Second EXIT retries
                 * only the retained owner and never returns on success. */
                (void)dsys_exit(CHILD_STATUS);
                (void)dsys_halt();''',
        '''                /* First EXIT closed reader and control PIPE. Both
                 * child-owned PIPE writer and regular FILE are still live. */
                if (dsys_meminfo(&child_state) != 0 ||
                    child_state.file_slots_used != 2UL)
                        (void)dsys_halt();
                /* Second EXIT commits the PIPE free, but its independent
                 * VFS_SYNC refusal retains only the regular FILE FD6. */
                if (dsys_exit(CHILD_STATUS) != -1 ||
                    dsys_meminfo(&child_state) != 0 ||
                    child_state.file_slots_used != 1UL)
                        (void)dsys_halt();
                /* Third EXIT sees only FD6 and retires that provider
                 * after its separately held refusal budget is consumed. */
                (void)dsys_exit(CHILD_STATUS);
                (void)dsys_halt();''')
    guest_c = once(guest_c,
        '''        child = spawn_child(rd, wr, ctrl_rd);''',
        '''        regular_fd = dsys_open(regular_path, SYS_O_RDONLY);
        if (regular_fd != 7)
                fail('f');
        child = spawn_child(rd, wr, ctrl_rd, regular_fd);''')
    guest_c = once(guest_c,
        '''            dsys_close(ctrl_rd) != 0)''',
        '''            dsys_close(ctrl_rd) != 0 ||
            dsys_close(regular_fd) != 0)''')
    guest_path = work / 'daimos-k02-run-mixed-exit-v1724.generated.c'
    guest_path.write_text(guest_c)

    script = script_path.read_text().replace('v1723', 'v1724')
    script = once(script,
        'self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)',
        "self='%s'" % selfdir)
    script = once(script,
        '"$self/daimos-k02-run-pipe-exit-v1724.c"',
        '"%s"' % guest_path)

    # Only target the child's FD6 vnode (not any other VFS SYNC, even
    # when a provider, kind and mount coincide). The production sync
    # implementation executes unchanged after the two injected errors.
    hook = """python3 - "$work/source/system/kernel/fs/vfs.s" <<'PYV1724'
from pathlib import Path
import sys
p = Path(sys.argv[1]); s = p.read_text()
old = '''vfs_sync:
        ldb     7,[POINT 6,1,5]'''
new = '''vfs_sync:
        ; Test-only: reject the child-owned FD6 filesystem sync twice.
        push    17,2
        move    2,proc_current_slot
        caie    2,2
        jrst    vfs_sync_orig_v1724
        move    2,file_table
        jumpe   2,vfs_sync_orig_v1724
        move    2,014(2)               ; FD6 first word
        jumpe   2,vfs_sync_orig_v1724
        tlz     2,700070               ; v417 canonical vnode
        came    1,2
        jrst    vfs_sync_orig_v1724
        aos     daimos_provcalls_v1724
        move    2,daimos_provcalls_v1724
        caile   2,2
        jrst    vfs_sync_orig_v1724
        aos     daimos_provrefuse_v1724
        pop     17,2
        movni   1,5                    ; injected VFS -5 only
        popj    17,
vfs_sync_orig_v1724:
        pop     17,2
        ldb     7,[POINT 6,1,5]'''
assert s.count(old) == 1, 'v1724: VFS_SYNC injection anchor drift'
s = s.replace(old, new, 1)
s += '''
        .bss
        .globl daimos_provcalls_v1724
daimos_provcalls_v1724: .block 1
        .globl daimos_provrefuse_v1724
daimos_provrefuse_v1724: .block 1
'''
p.write_text(s)
PYV1724
"""
    script = once(script,
        'cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"\n',
        'cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"\n' + hook)
    script = once(script,
        'done\nsed -i -e \'s/^set wcnsls .*/set wcnsls disabled/\'',
        '''done
for pair in provcalls:daimos_provcalls_v1724 provrefuse:daimos_provrefuse_v1724; do
    name=${pair%%:*}
    sym=${pair#*:}
    addr=$(awk -v s="$sym" '$1 == s {print $2; exit}' "$build/kcore.map")
    test -n "$addr" || { echo "v1724: missing $sym" >&2; exit 1; }
    printf '%s %s\\n' "$name" "$addr" >> "$work/addresses"
done
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/\'''' )
    script = once(script,
        'expected = dict(calls=2, pins=1, unpins=1, busy=1, freed=1, errors=0)',
        'expected = dict(calls=2, pins=1, unpins=1, busy=1, freed=1, '\
        'errors=0, provcalls=3, provrefuse=2)')
    script = once(script,
        "print('v1724: 256K PDP-6 RUN child final PIPE EXIT, real MM pin/BUSY, '",
        "print('v1724: real RUN child: MM_BUSY and two VFS sync refusals, '")
    script = once(script,
        "      'retained FD, retry EXIT and parent WAIT PASS:', seen)",
        "      'independent FD retention, 3 EXIT passes, parent WAIT PASS:', seen)")
    (work / 'daimos-k02-run-mixed-exit-v1724.generated.sh').write_text(script)


if __name__ == '__main__':
    main()
