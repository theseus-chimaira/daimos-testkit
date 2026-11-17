#!/usr/bin/env python3
"""Move compressed child backing from selected root to native DTC3 DTFS.

Use the source-derived, previously accepted v1638 workload, retaining
the parent's root-based plain executable and the full PIPE/WAIT checks.
Only parent setup and compressed-child path differ. All actual file
creation and copying are performed by unchanged DAIMOS user syscalls.
"""

from pathlib import Path
import runpy
import sys


def generate(source):
    here = Path(__file__).resolve().parent
    stage = runpy.run_path(str(here.parent /
                                "pure-full-restore-v1638/prepare-v1638.py"))
    p37 = runpy.run_path(str(here.parent /
                               "pure-cache-pressure-v1637/prepare-v1637.py"))
    p36 = runpy.run_path(str(here.parent /
                               "pure-cache-low-v1636/prepare-v1636.py"))
    code = stage["generate"](source,
                             lambda s: p37["generate"](s, p36["generate"]))

    old = ("static kword_t p14_compressed_path[3] = {\n"
           "    12UL,\n"
           "    P14_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),\n"
           "    P14_SIX6('M', '/', 'C', 'O', 'M', 'P')\n"
           "};")
    replacement = """static kword_t p14_compressed_path[3] = {
    12UL,
    P14_SIX6('/', 'M', 'O', 'U', 'N', 'T'),
    P14_SIX6('/', 'D', 'T', '0', '/', 'C')
};
static kword_t p14_source_v1643[3] = {
    12UL,
    P14_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
    P14_SIX6('M', '/', 'C', 'O', 'M', 'P')
};
static kword_t p14_device_v1643[3] = {
    9UL,
    P14_SIX6('/', 'D', 'E', 'V', '/', 'D'),
    P14_SIX6('T', 'C', '3', ' ', ' ', ' ')
};
static kword_t p14_mount_v1643[3] = {
    10UL,
    P14_SIX6('/', 'M', 'O', 'U', 'N', 'T'),
    P14_SIX6('/', 'D', 'T', '0', ' ', ' ')
};

/* No permanent kernel, filesystem, or new file format support.
 * Seed a genuine independent mounted DTFS file from the original
 * verified root compressed DXR, using ordinary kernel syscalls.
 * All FDs are closed before starting any sleeping child.
 */
static int
p14_seed_secondary_v1643(void)
{
    kword_t buffer[0200];
    struct sys_fsinfo info;
    int src, dst, n;

    if (dsys_dtfs_mount(p14_device_v1643, p14_mount_v1643,
            SYS_DTFS_TYPE_NATIVE) != 0)
        return -1;
    if (dsys_fsinfo(1U, &info) != 1 ||
        info.provider != 5UL || info.mount_id != 2UL)
        return -2;
    src = dsys_open(p14_source_v1643, SYS_O_RDONLY);
    if (src < 0)
        return -3;
    dst = dsys_open(p14_compressed_path,
                    SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
    if (dst < 0) {
        (void)dsys_close(src);
        return -4;
    }
    for (;;) {
        n = dsys_read_words(src, buffer, 0200U);
        if (n <= 0)
            break;
        if (dsys_write_words(dst, buffer, (unsigned int)n) != n) {
            n = -1;
            break;
        }
    }
    if (dsys_close(dst) != 0 || dsys_close(src) != 0 || n < 0)
        return -5;
    if (dsys_chmod(p14_compressed_path, 0555U) != 0)
        return -6;
    return 0;
}
"""
    assert code.count(old) == 1
    code = code.replace(old, replacement, 1)
    old = "    if (p14_pipe(&rd, &wr) != 0)"
    new = "    if (p14_seed_secondary_v1643() != 0)\n        p14_fail('f');\n" + old
    assert code.count(old) == 1
    code = code.replace(old, new, 1)
    for marker in ("#define P14_CHILDREN         6U",
                   "pid[i] = p14_spawn(rd, i != 0U);",
                   "denied = p14_spawn(rd, 1U);",
                   "dsys_wait((unsigned int)pid[i], &status, 0U)",
                   "(void)p14_char('Z');"):
        assert marker in code
    return code


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-v1643.py original.c output.c")
    result = generate(Path(sys.argv[1]).read_text(encoding="ascii"))
    Path(sys.argv[2]).write_text(result, encoding="ascii")
    print("v1643: one root plain and five genuine DTC3 DTFS compressed PURE")


if __name__ == "__main__":
    main()
