#!/usr/bin/env python3
"""Build a provider-entry K02 guest from the accepted mixed-EXIT v1724 case.

Only a copied D6FS MRES source is patched. VFS, FILE, RUN, the provider
serialization gateway and the MM allocator are production implementations.
"""

from pathlib import Path
import subprocess
import sys


def replace_one(source, old, new):
    count = source.count(old)
    if count != 1:
        raise SystemExit("v1725: expected one anchor, found %d: %r" %
                         (count, old[:100]))
    return source.replace(old, new, 1)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: v1725.py VERSIONED_WORKDIR TEST_DIR")

    work = Path(sys.argv[1]).resolve()
    root = Path(sys.argv[2]).resolve()
    previous = root / "daimos-k02-run-mixed-exit-v1724.py"
    subprocess.run([
        sys.executable, str(previous),
        str(root / "daimos-k02-run-pipe-exit-v1723.sh"),
        str(root / "daimos-k02-run-pipe-exit-v1723.c"),
        str(work), str(root)], check=True)

    src = work / "daimos-k02-run-mixed-exit-v1724.generated.sh"
    script = (src.read_text().replace("v1724", "v1725")
              .replace("PYV1724", "PYV1725"))
    source_c = work / "daimos-k02-run-mixed-exit-v1724.generated.c"
    dest_c = work / "daimos-k02-run-provider-lease-v1725.generated.c"
    dest_c.write_text(source_c.read_text().replace("v1724", "v1725"))
    script = replace_one(script,
        "daimos-k02-run-mixed-exit-v1725.generated.c",
        dest_c.name)

    # Remove the old injection at vfs_sync completely, and instead inject
    # at the D6FS provider's own registered FS_MRES_OP_SYNC entry.
    first = "python3 - \"$work/source/system/kernel/fs/vfs.s\" <<'PYV1725'\n"
    last = "\nPYV1725\n"
    if script.count(first) != 1:
        raise SystemExit("v1725: v1724 VFS fault hook missing")
    start = script.index(first)
    stop = script.index(last, start) + len(last)
    provider = r"""python3 - "$work/source/system/kernel/fs/d6fs_runtime.s" <<'PYV1725'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()
old = '''d6fs_provider_sync:
        jrst    kret_zero'''
new = '''d6fs_provider_sync:
        ; Test-only. This function is reached THROUGH FS_MRES_OP_SYNC,
        ; after the resident filesystem gateway has acquired its lease.
        move    2,proc_current_slot
        caie    2,2                     ; only the real RUN child
        jrst    kret_zero
        move    2,file_table
        jumpe   2,kret_zero
        move    2,014(2)               ; child FD6 canonical vnode
        jumpe   2,kret_zero
        tlz     2,700070               ; remove FILE flags, not mount
        came    1,2
        jrst    kret_zero
        aos     daimos_provcalls_v1725
        ; A real serialized provider call owns fs_provider_ready with
        ; LH=(child_slot+1), RH=0. This distinguishes MRES dispatch
        ; from an invented VFS-entry stub returning an error directly.
        hlrz    2,fs_provider_ready
        caie    2,3
        aos     daimos_leasebad_v1725
        hrrz    2,fs_provider_ready
        jumpe   2,daimos_leasegood_entry_v1725
        aos     daimos_leasebad_v1725
daimos_leasegood_entry_v1725:
        aos     daimos_leaseok_v1725
        move    2,daimos_provcalls_v1725
        caile   2,2
        jrst    kret_zero               ; production success, third try
        aos     daimos_provrefuse_v1725
        seto    1,                      ; provider-originated refusal
        popj    17,'''
assert s.count(old) == 1, 'v1725: D6FS provider SYNC anchor drift'
s = s.replace(old, new, 1)
p.write_text(s)

# D6FS runs as a movable MRES, whose map symbols are module-relative.
# Keep the four test witnesses in the copied *resident* fs_mres.s, so
# SIMH examines stable physical KCORE words and D6FS can resolve them
# through the ordinary KCORE symbol map. No production data are added.
kp = p.with_name('fs_mres.s')
ks = kp.read_text()
for name in ('provcalls', 'provrefuse', 'leaseok', 'leasebad'):
    sym = 'daimos_' + name + '_v1725'
    assert sym not in ks, 'v1725: duplicate KCORE witness ' + sym
    ks += '\n        .bss\n        .globl ' + sym + '\n' + sym + ': .block 1\n'
kp.write_text(ks)
PYV1725
"""
    script = script[:start] + provider + script[stop:]
    script = replace_one(script,
        'for pair in provcalls:daimos_provcalls_v1725 '
        'provrefuse:daimos_provrefuse_v1725; do',
        'for pair in provcalls:daimos_provcalls_v1725 '
        'provrefuse:daimos_provrefuse_v1725 '
        'leaseok:daimos_leaseok_v1725 leasebad:daimos_leasebad_v1725; do')
    script = replace_one(script,
        'provrefuse=2)',
        'provrefuse=2, leaseok=3, leasebad=0)')
    script = replace_one(script,
        'v1725: real RUN child: MM_BUSY and two VFS sync refusals, ',
        'v1725: RUN child PIPE MM_BUSY and two D6FS provider refusals, ')
    script = replace_one(script,
        'independent FD retention, 3 EXIT passes, parent WAIT PASS:',
        'provider lease identity, 3 EXIT passes, parent WAIT PASS:')

    (work / "daimos-k02-run-provider-lease-v1725.generated.sh").write_text(script)


if __name__ == "__main__":
    main()
