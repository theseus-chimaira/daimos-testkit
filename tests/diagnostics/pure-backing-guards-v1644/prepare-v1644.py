#!/usr/bin/env python3
"""Source-build v1644: real writable DTFS PURE backing lifetime gates.

Derive the fully accepted v1643 child workload; do not modify its six
child data/PIPE/EXIT/WAIT contracts. The source is kept writable for
testing real PURE busy guards rather than read-only mount rejection.
"""

from pathlib import Path
import runpy
import sys


def generate(original):
    here = Path(__file__).resolve().parent
    source = runpy.run_path(str(here.parent /
                                 "pure-secondary-read-v1643/prepare-v1643.py"))
    code = source["generate"](original)
    replacements = [
        ("dsys_chmod(p14_compressed_path, 0555U)",
         "dsys_chmod(p14_compressed_path, 0777U)"),
        ("SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0",
         "SYS_DTFS_TYPE_NATIVE) != 0"),
    ]
    for old, new in replacements:
        assert code.count(old) == 1, old
        code = code.replace(old, new, 1)
    # The initial file is RW on the original real native DTFS volume.
    # The exact compressed source remains byte-identical to the ROOT DXR.
    anchor = "    if (p14_pipe(&rd, &wr) != 0)"
    assert code.count(anchor) == 1
    guards = """    /* The v1644 file source is on an actually writable DTC3 mount.
     * The current source is 0777, so refused writes/truncates cannot be
     * attributed merely to permissions or an RO mount. No test edits
     * the executable contents, even temporarily.
     */
"""
    code = code.replace(anchor, guards + anchor, 1)

    # The original v1643 seed routine precedes p14_char/p14_fail.  Place
    # these new helpers after the original output/error definitions so
    # strict C89 needs no implicit forward declarations.
    marker = "static void\np14_spin(void)"
    assert code.count(marker) == 1
    guard_functions = """static kword_t p14_renamed_v1644[3] = {
    11UL,
    P14_SIX6('/', 'M', 'O', 'U', 'N', 'T'),
    P14_SIX6('/', 'S', 'A', 'F', 'E', ' ')
};

/* Called only AFTER the parent's A snapshot and BEFORE it releases
 * the PIPE writer. The children are still sleeping and genuinely
 * PACKED. Every syscall uses the public DAIMOS ABI, not MM stubs.
 */
static void
p14_check_busy_v1644(void)
{
    kword_t sentinel = 056712345670UL;
    struct sys_fsinfo info;
    struct vfs_stat st;
    int fd;

    if (dsys_fsinfo(1U, &info) != 1 ||
        info.provider != 5UL || info.mount_id != 2UL)
        p14_fail('1');
    if (dsys_unmount(p14_mount_v1643) == 0)
        p14_fail('2');
    if (dsys_unlink(p14_compressed_path) == 0)
        p14_fail('3');
    if (dsys_truncate(p14_compressed_path, 0UL) == 0)
        p14_fail('4');
    fd = dsys_open(p14_compressed_path, SYS_O_WRONLY | SYS_O_TRUNC);
    if (fd >= 0) {
        (void)dsys_close(fd);
        p14_fail('5');
    }
    fd = dsys_open(p14_compressed_path, SYS_O_RDWR);
    if (fd < 0)
        p14_fail('6');
    if (dsys_write_words(fd, &sentinel, 1U) >= 0)
        p14_fail('7');
    if (dsys_close(fd) != 0)
        p14_fail('8');
    if (dsys_stat(p14_compressed_path, &st) != 0)
        p14_fail('9');

    /* RENAME changes native DTFS directory spelling in the SAME slot;
     * the original executable vnode identity and source data remain
     * unchanged. It is intentionally a positive test, not a guard.
     */
    if (dsys_rename(p14_compressed_path, p14_renamed_v1644) != 0)
        p14_fail('a');
    if (dsys_stat(p14_renamed_v1644, &st) != 0 ||
        dsys_stat(p14_compressed_path, &st) == 0)
        p14_fail('b');
    if (dsys_unlink(p14_renamed_v1644) == 0)
        p14_fail('c');
    if (dsys_rename(p14_renamed_v1644, p14_compressed_path) != 0 ||
        dsys_stat(p14_compressed_path, &st) != 0)
        p14_fail('d');
    (void)p14_char('P');
}

static void
p14_check_released_v1644(void)
{
    struct sys_fsinfo info;
    if (dsys_unmount(p14_mount_v1643) != 0 ||
        dsys_fsinfo(1U, &info) != 0)
        p14_fail('e');
    (void)p14_char('U');
}

"""
    code = code.replace(marker, guard_functions + marker, 1)
    after = "    p14_stat('A');"
    assert code.count(after) == 1
    code = code.replace(after, after + "\n    p14_check_busy_v1644();", 1)
    before_final = "    (void)p14_char('Z');"
    assert code.count(before_final) == 1
    code = code.replace(before_final,
                        "    p14_check_released_v1644();\n" + before_final, 1)
    for fragment in ("#define P14_CHILDREN         6U",
                     "denied = p14_spawn(rd, 1U);",
                     "dsys_wait((unsigned int)pid[i], &status, 0U)",
                     "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                     "(void)p14_char('P');", "(void)p14_char('U');"):
        assert fragment in code
    return code


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-v1644.py original.c output.c")
    code = generate(Path(sys.argv[1]).read_text(encoding="ascii"))
    Path(sys.argv[2]).write_text(code, encoding="ascii")
    print("v1644: real RW DTC3 backed PURE mutation/unmount/rename checks")


if __name__ == "__main__":
    main()
