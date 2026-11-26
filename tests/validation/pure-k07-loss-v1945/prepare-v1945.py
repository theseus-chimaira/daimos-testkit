#!/usr/bin/env python3
"""Use the accepted pressure child and independently guest-seeded DTFS child."""
from pathlib import Path
import sys

s = Path(sys.argv[1]).read_text(encoding="ascii")

def replace(old, new):
    global s
    assert s.count(old) == 1, old
    s = s.replace(old, new, 1)

replace("#define P14_CHILDREN         5U", "#define P14_CHILDREN         7U")
replace("P14_SIX6('M', '/', 'I', 'N', 'I', 'T')", "P14_SIX6('M', '/', 'B', 'A', 'S', 'E')")
replace("""    12UL,
    P14_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
    P14_SIX6('M', '/', 'C', 'O', 'M', 'P')""", """    11UL,
    P14_SIX6('/', 'M', 'O', 'U', 'N', 'T'),
    P14_SIX6('/', 'C', 'O', 'M', 'P', ' ')""")
replace("static int\np14_char(int c)", """static kword_t device[3] = {
    9UL, P14_SIX6('/', 'D', 'E', 'V', '/', 'D'),
    P14_SIX6('T', 'C', '3', ' ', ' ', ' ')
};
static kword_t mountpath[3] = {
    6UL, P14_SIX6('/', 'M', 'O', 'U', 'N', 'T'), 0UL
};

static int
p14_char(int c)""")
replace("    unsigned int i;\n    kword_t old_brk", "    unsigned int i, count;\n    kword_t old_brk")
start = s.index("    if (p14_pipe(&rd, &wr) != 0)", s.index("int\nmain("))
end = s.index("    if (dsys_close(rd) != 0)", start)
s = s[:start] + """    {
        struct sys_fsinfo fs;
        struct vfs_stat st;
        if (dsys_dtfs_mount(device, mountpath,
                SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0 ||
            dsys_fsinfo(1U, &fs) != 1 || fs.provider != 5UL ||
            fs.mount_id != 2UL ||
            dsys_stat(p14_compressed_path, &st) != 0 ||
            st.type != VFS_TYPE_REG || st.size_words != 999UL)
            p14_fail('b');
    }
    (void)p14_char('I');
    if (p14_pipe(&rd, &wr) != 0)
        p14_fail('p');
    /* Slot 3 is the genuine secondary compressed child. Other children
     * have the accepted v1942 large root-backed image. Force real MM
     * pressure by admitting until the first checked refusal. */
    for (count = 0U; count < P14_CHILDREN; ++count) {
        denied = p14_spawn(rd, count == 1U);
        if (denied == -1)
            break;
        if (denied <= 1 || !p14_sleeping((unsigned int)denied))
            p14_fail('r');
        pid[count] = denied;
        (void)p14_char('a');
    }
    if (count < 4U || count == P14_CHILDREN)
        p14_fail('u');
    (void)p14_char('x');
""" + s[end:]
s = s.replace("i < P14_CHILDREN", "i < count")
# The new mount/stat code may change the parent's initial BRK. The
# no-growth query must use the actual unchanged current value.
replace("    target = P14_BRK_TARGET;", "    target = old_brk;")
replace("    (void)p14_char('Z');", """    if (dsys_unmount(mountpath) != 0)
        p14_fail('U');
    (void)p14_char('Z');""")
Path(sys.argv[2]).write_text(s, encoding="ascii")
