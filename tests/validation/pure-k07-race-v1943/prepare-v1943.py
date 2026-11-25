#!/usr/bin/env python3
"""Derive a two-actor physical race guest from the accepted source fixture."""
from pathlib import Path
import runpy
import sys

here = Path(__file__).resolve().parent
old = here.parent.parent / "diagnostics" / "pure-quiesce-run-v1646" / "prepare-v1646.py"
source = runpy.run_path(str(old))["generate"](Path(sys.argv[1]).read_text())
# A smaller private image avoids unrelated reclaim in this ordering test.
assert source.count("#define P14_IMAGE_WORDS      04000U") == 1
source = source.replace("#define P14_IMAGE_WORDS      04000U",
                        "#define P14_IMAGE_WORDS      01000U")
a = """    if (dsys_unmount(p14_mount_v1643) != 0)
        return 063;
    (void)p14_char('V');"""
b = """    if (value == 017654321076UL) {
        if (dsys_sleep(02000U) != 0)
            return 064;
        if (dsys_unmount(p14_mount_v1643) != -1)
            return 065;
        (void)p14_char('D');
        return 0;
    }
    if (dsys_unmount(p14_mount_v1643) != 0)
        return 063;
    (void)p14_char('V');"""
assert source.count(a) == 1
source = source.replace(a, b, 1)
a = "value != 027643210765UL)"
assert source.count(a) == 1
source = source.replace(a, "(value != 027643210765UL && value != 017654321076UL))", 1)
# Same helper, alternate PIPE token: reverse race while RUN is in loader.
a = "int\nmain(int argc, kword_t **argv)"
helper = """static void
p14_reservation_race_v1943(void)
{
    int rd, wr, cr, cw, actor, child;
    kword_t token = 017654321076UL, status = 0UL;
    if (p14_pipe(&rd, &wr) != 0 || p14_pipe(&cr, &cw) != 0)
        p14_fail('g');
    actor = p14_spawn_unmounter_v1646(cr);
    if (actor <= 1 || dsys_close(cr) != 0)
        p14_fail('j');
    if (dsys_write_words(cw, &token, 1U) != 1)
        p14_fail('k');
    (void)p14_char('E');
    child = p14_spawn(rd, 1U);
    if (child <= 1 || !p14_sleeping((unsigned int)child))
        p14_fail('r');
    (void)p14_char('F');
    if (dsys_wait((unsigned int)actor, &status, 0U) != actor ||
        SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
        SYS_WAIT_STATUS_VALUE(status) != 0U)
        p14_fail('h');
    if (dsys_close(cw) != 0 || dsys_close(rd) != 0 ||
        dsys_close(wr) != 0)
        p14_fail('c');
    if (dsys_wait((unsigned int)child, &status, 0U) != child ||
        SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
        SYS_WAIT_STATUS_VALUE(status) != P14_STATUS)
        p14_fail('i');
    (void)p14_char('G');
}

"""
assert source.count(a) == 1
source = source.replace(a, helper + a, 1)
# Preserve original child branches, replace only parent's workload.
a = "    {\n        int seed_result = p14_seed_secondary_v1643();"
i = source.index(a, source.index("int\nmain("))
source = source[:i] + """    if (p14_seed_secondary_v1643() != 0)
        p14_fail('b');
    (void)p14_char('I');
    p14_reservation_race_v1943();
    p14_quiesce_run_v1646();
    p14_check_released_v1644();
    (void)p14_char('Z');
    (void)dsys_exit(0);
    return 0;
}
"""
Path(sys.argv[2]).write_text(source, encoding="ascii")
