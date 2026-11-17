#!/usr/bin/env python3
"""v1646: an actual PURE RUN challenges a sleeping DTFS V2 unmount.

Derive v1645's actual PIPE/private-DATA/WAIT checks. Retain one plain
ROOT and one compressed secondary PURE child; six-child 48K memory
pressure was established independently by v1645, while this larger
race-test executable genuinely changes the physical BCACHE geometry.
After both owners retire, a root-backed sibling unmounts native DTFS
while PID1 challenges the live quiescence boundary with a real RUN.
"""

from pathlib import Path
import runpy
import sys


def generate(original):
    here = Path(__file__).resolve().parent
    prior = runpy.run_path(str(here.parent /
                                "pure-pi6-backing-v1645/prepare-v1645.py"))
    source = prior["generate"](original)

    # This is a transaction/scheduler race test, NOT another assertion
    # that exactly six large 8K guest images fit into 48K. The extra
    # actor and race code grows TX2 and compressed data, and thereby
    # consumes more physical BCACHE. Retain only the two necessary
    # independent backing owners; verify both actual EXIT/WAIT paths.
    assert source.count("#define P14_CHILDREN         6U") == 1
    source = source.replace("#define P14_CHILDREN         6U",
                            "#define P14_CHILDREN         2U", 1)
    refused = ("    /* Seventh RUN forces real RAW memory pressure; it\n"
               "     * cannot acquire a seventh complete child APR. The\n"
               "     * parent must survive and reap its six existing kids.\n"
               "     */\n"
               "    denied = p14_spawn(rd, 1U);\n"
               "    if (denied != -1)\n"
               "        p14_fail('u');\n"
               "    (void)p14_char('x');\n")
    assert source.count(refused) == 1
    source = source.replace(refused, "", 1)
    assert source.count("int rd, wr, pid[P14_CHILDREN], got, denied;") == 1
    source = source.replace("int rd, wr, pid[P14_CHILDREN], got, denied;",
                            "int rd, wr, pid[P14_CHILDREN], got;", 1)
    # v1645's constant no-growth break applied to its smaller TX2
    # executable. The extra v1646 actor/race code legitimately raises
    # the initial data break. Compare against the actual original BRK
    # value, preserving precisely the same no-growth syscall invariant.
    assert source.count("    target = P14_BRK_TARGET;") == 1
    source = source.replace("    target = P14_BRK_TARGET;",
                            "    target = old_brk;", 1)

    # A source-backed plain TSFS helper has no executable backing reference
    # to the secondary DTFS volume. It waits on its inherited anonymous
    # PIPE fd0, then calls the real unmount syscall and exits normally.
    funcs = """static int
p14_spawn_unmounter_v1646(int rd)
{
    kword_t block[P14_BLOCK_WORDS];
    struct sys_run_v2 *run = (struct sys_run_v2 *)block;
    unsigned int i;
    for (i = 0U; i < P14_BLOCK_WORDS; ++i)
        block[i] = 0UL;
    run->flags = SYS_RUN_PGRP_INHERIT;
    run->pgrp = 0UL;
    run->fdmap_count = 3UL;
    run->argc = 2UL;
    run->envc = 0UL;
    for (i = 0U; i < P14_PATH_WORDS; ++i) {
        block[P14_PATH_OFF + i] = p14_path[i];
        block[P14_ARG0_OFF + i] = p14_path[i];
    }
    block[P14_ARG1_OFF] = 1UL;
    block[P14_ARG1_OFF + 1U] =
        P14_SIX6('U', ' ', ' ', ' ', ' ', ' ');
    block[P14_MAP_OFF] = SYS_RUN_FD_MAP(0U, (unsigned int)rd);
    block[P14_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
    block[P14_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
    run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
        P14_BLOCK_WORDS);
    return dsys_run(run);
}

static int
p14_unmounter_v1646(void)
{
    kword_t value = 0UL;
    if (dsys_read_words(0, &value, 1U) != 1 ||
        value != 027643210765UL)
        return 061;
    if (dsys_close(0) != 0)
        return 062;
    if (dsys_unmount(p14_mount_v1643) != 0)
        return 063;
    (void)p14_char('V');
    return 0;
}

static void
p14_quiesce_run_v1646(void)
{
    struct sys_fsinfo info;
    kword_t token = 027643210765UL;
    kword_t status = 0UL;
    int control_rd, control_wr, restore_rd, restore_wr;
    int unmounter, child, result;
    unsigned int attempts;

    if (p14_pipe(&control_rd, &control_wr) != 0 ||
        p14_pipe(&restore_rd, &restore_wr) != 0)
        p14_fail('q');
    unmounter = p14_spawn_unmounter_v1646(control_rd);
    if (unmounter <= 1 || dsys_close(control_rd) != 0)
        p14_fail('j');
    /* v1647: Keep the control writer open while probing quiescence.
     * Closing it here can give the unmount helper an extra scheduler
     * window before the parent observes the original V2 barrier.
     * The helper has received its one-word token and needs no EOF.
     */
    if (dsys_write_words(control_wr, &token, 1U) != 1)
        p14_fail('k');
    (void)p14_char('S');

    /* This refuses a test which merely races too late, after the mount
     * slot has already been retired. A live slot returns 1, a slot held
     * by the original V2 quiescence barrier returns -1, and a retired
     * slot returns 0.  Only a real provider refusal is a valid witness.
     */
    for (attempts = 0U; attempts < 03000U; ++attempts) {
        result = dsys_fsinfo(1U, &info);
        if (result < 0)
            break;
        if (result == 0)
            p14_fail('l');
        if (dsys_sleep(1U) != 0)
            p14_fail('t');
    }
    if (attempts == 03000U)
        p14_fail('m');
    (void)p14_char('Q');

    /* A real DXR2 compressed PURE RUN, not an OPEN/CHDIR surrogate.
     * Only original file/provider admission may refuse this attempt.
     * Do not discard, edit or fabricate a PURE owner record in MM.
     */
    child = p14_spawn(restore_rd, 1U);
    if (child != -1 || dsys_fsinfo(1U, &info) >= 0)
        p14_fail('n');
    (void)p14_char('R');
    status = 0UL;
    if (dsys_wait((unsigned int)unmounter, &status, 0U) != unmounter ||
        SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
        SYS_WAIT_STATUS_VALUE(status) != 0U ||
        dsys_fsinfo(1U, &info) != 0 ||
        dsys_close(control_wr) != 0)
        p14_fail('o');

    /* The real mount can now be reinstalled with the exact same DTC3
     * volume; the rejected RUN did not corrupt its DXR or ownership.
     */
    if (dsys_dtfs_mount(p14_device_v1643, p14_mount_v1643,
                       SYS_DTFS_TYPE_NATIVE) != 0 ||
        dsys_fsinfo(1U, &info) != 1 ||
        info.provider != 5UL || info.mount_id != 2UL)
        p14_fail('p');
    (void)p14_char('M');
    child = p14_spawn(restore_rd, 1U);
    if (child <= 1 || dsys_close(restore_rd) != 0 ||
        dsys_close(restore_wr) != 0)
        p14_fail('r');
    status = 0UL;
    if (dsys_wait((unsigned int)child, &status, 0U) != child ||
        SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
        SYS_WAIT_STATUS_VALUE(status) != P14_STATUS)
        p14_fail('s');
    (void)p14_char('A');
}

"""
    anchor = "int\nmain(int argc, kword_t **argv)"
    assert source.count(anchor) == 1
    source = source.replace(anchor, funcs + anchor, 1)
    old = "    if (argc > 1) {\n        {\n            int nread ="
    new = ("    if (argc > 1 && argv != 0 && argv[1] != 0 &&\n"
           "        argv[1][0] == 1UL &&\n"
           "        argv[1][1] == P14_SIX6('U', ' ', ' ', ' ', ' ', ' ')) {\n"
           "        (void)dsys_exit(p14_unmounter_v1646());\n"
           "        return 0;\n"
           "    }\n" + old)
    assert source.count(old) == 1
    source = source.replace(old, new, 1)
    after_wait = "    p14_check_released_v1644();"
    assert source.count(after_wait) == 1
    source = source.replace(after_wait,
                            "    p14_quiesce_run_v1646();\n" + after_wait, 1)
    for fragment in ("#define P14_CHILDREN         2U",
                     "(void)p14_char('H');", "(void)p14_char('T');",
                     "p14_check_busy_v1644();",
                     "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                     "p14_quiesce_run_v1646();",
                     "(void)p14_char('Q');", "(void)p14_char('R');"):
        assert fragment in source
    return source


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-v1646.py original.c output.c")
    code = generate(Path(sys.argv[1]).read_text(encoding="ascii"))
    Path(sys.argv[2]).write_text(code, encoding="ascii")
    print("v1646: compressed PURE RUN during original V2 unmount quiescence")


if __name__ == "__main__":
    main()
