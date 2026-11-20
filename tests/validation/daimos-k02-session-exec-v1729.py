#!/usr/bin/env python3
"""Create an isolated 256K PDP-6 session/D6FS/fatal-EXEC integration test."""

from pathlib import Path
import sys


def one(text, before, after):
    n = text.count(before)
    if n != 1:
        raise SystemExit("v1729: source anchor count %d: %r" %
                         (n, before[:105]))
    return text.replace(before, after, 1)


def make_guest(root, work):
    src = (root / 'daimos-session-hup-physical-v907.c').read_text()
    src = one(src, '#include "../test_sixbit.h"',
              '#include "%s"' % (root.parent / 'test_sixbit.h'))
    src = one(src,
              "        (void)dsys_writechar(1, ch);\n",
              "        (void)dsys_writechar(1, ch);\n"
              "        /* Failed INIT must still halt so the physical "
              "owner witnesses are examined. */\n"
              "        (void)dsys_halt();\n")
    src = one(src, '#define JOB_MODE             0432U',
              '#define JOB_MODE             0432U\n'
              '#define EXEC_MODE            0433U')
    src = one(src, "mode_ch = mode == LEADER_MODE ? 'L' : 'J';",
              "mode_ch = mode == LEADER_MODE ? 'L' : "
              "(mode == EXEC_MODE ? 'E' : 'J');")
    src = one(src, "        if (ch == 'J')\n                return JOB_MODE;",
              "        if (ch == 'J')\n                return JOB_MODE;\n"
              "        if (ch == 'E')\n                return EXEC_MODE;")
    src = one(src, "static int\nnew_pipe(int *read_fd, int *write_fd)",
              """static int
exec_self_v1729(void)
{
        kword_t block[SYS_EXEC_V1_FIXED_WORDS + RUN_PATH_WORDS];
        struct sys_exec_v1 *req;
        unsigned int i;

        for (i = 0U; i < sizeof(block) / sizeof(block[0]); ++i)
                block[i] = 0UL;
        req = (struct sys_exec_v1 *)block;
        req->version_words = SYS_RUN_HEADER(SYS_EXEC_VERSION_1,
            SYS_EXEC_V1_FIXED_WORDS + RUN_PATH_WORDS);
        req->argc = 0UL;
        req->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i)
                block[SYS_EXEC_V1_FIXED_WORDS + i] = init_path[i];
        return dsys_exec(req);
}

static int
new_pipe(int *read_fd, int *write_fd)""")
    src = one(src, "        if (mode == JOB_MODE) {",
              """        if (mode == EXEC_MODE) {
                if (dsys_getpid() != 5)
                        fail('e', 0222);
                (void)exec_self_v1729();
                fail('X', 0223); /* Destroyed VM must never resume. */
        }
        if (mode == JOB_MODE) {""")
    src = one(src,
              "                if (dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=",
              """                if (dsys_getpid() == 4) {
                        volatile kword_t *bad;
                        struct sys_meminfo live;
                        int fd;
                        fd = dsys_open(init_path, SYS_O_RDONLY);
                        if (fd != 3)
                                fail('F', 0224);
                        if (dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=
                            (int)SYS_TTY_ATTACHED(0U))
                                fail('G', 0224);
                        /* Refuse FD3 from the real D6FS MRES SYNC.
                         * The first ordinary EXIT retains FD3; a
                         * genuine APR fault then moves this process
                         * onto its protected private fatal stack.
                         */
                        if (dsys_exit(052U) != -1 ||
                            dsys_meminfo(&live) != 0 ||
                            live.file_slots_used != 1UL)
                                fail('B', 0224);
                        bad = (volatile kword_t *)0777777UL;
                        (void)*bad;
                        fail('X', 0224);
                }
                if (dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=""")
    src = one(src, "        int job2;\n#ifdef DAIMOS_V1154_PI6_DISK_SPIN",
              "        int job2;\n        int exec_pid;\n"
              "        int retry;\n"
              "        kword_t status;\n"
              "        struct sys_meminfo before_exec;\n"
              "        struct sys_meminfo after_exec;\n"
              "#ifdef DAIMOS_V1154_PI6_DISK_SPIN")
    start = src.index("        /* First HUP fails after a committed child, second retries it. */")
    end = src.index("        (void)dsys_exit(0);\n        return 0;\n}", start)
    src = src[:start] + """        /* Wait for job2's REAL owner-side D6FS refusal to enter
         * the protected fatal FILE close continuation. The test
         * never forges the FATAL_CLOSE bit or target FILE table.
         * The leader must now refuse all subsequent session HUPs.
         */
        for (retry = 0; retry < 64; ++retry) {
                if (dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                    (unsigned int)job2) == 1)
                        break;
                if (dsys_sleep(020U) != 0)
                        fail('u', 0225);
        }
        if (retry == 64)
                fail('v', 0225);
        if (dsys_meminfo(&before_exec) != 0)
                fail('w', 0225);
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG((unsigned int)leader, SYS_EVENT_HUP)) != -1)
                fail('6', 0206);
        status = 0UL;
        if (dsys_wait((unsigned int)leader, &status,
            SYS_WAIT_NOHANG) != 0)
                fail('q', 0210);
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG((unsigned int)leader, SYS_EVENT_HUP)) != -1)
                fail('7', 0207);
        /* Separate RUN child does destructive EXEC while job2 retains
         * FD3 and the leader still owns its attached session TTY.
         */
        exec_pid = spawn(EXEC_MODE, SYS_RUN_PGRP_NEW, 0U, -1);
        if (exec_pid != 5)
                fail('e', 0226);
        status = 0UL;
        if (dsys_wait((unsigned int)exec_pid, &status, 0U) != exec_pid ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 1U)
                fail('E', 0227);
        if (dsys_meminfo(&after_exec) != 0 ||
            after_exec.process_slots_used != before_exec.process_slots_used ||
            after_exec.file_slots_used != before_exec.file_slots_used)
                fail('m', 0230);
        /* INIT cannot WAIT on job2 while its session leader remains
         * alive and is still its parent. The kernel-side session
         * failure probe checks job2's stable FD3 at each refusal.
         */
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG((unsigned int)leader, SYS_EVENT_HUP)) != -1 ||
            dsys_wait((unsigned int)leader, &status,
                SYS_WAIT_NOHANG) != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != -1)
                fail('h', 0231);
        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
""" + src[end:]
    target = work / 'daimos-k02-session-exec-v1729.generated.c'
    target.write_text(src)
    return target


def make_runner(root, work, guest):
    src = (root / 'daimos-session-hup-physical-v907.sh').read_text()
    src = one(src, 'daimos-session-hup-physical-v907.XXXXXX',
              'daimos-k02-session-exec-guest-v1729.XXXXXX')
    src = one(src, 'self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)',
              "self='%s'" % root)
    src = one(src, '-S "$self/daimos-session-hup-physical-v907.c"',
              '-S "%s"' % guest)

    # Install probes AFTER the baseline v907 test-only first-member
    # MM-pin hook, but before any full-system build/assembly.
    before = ('path.write_text(source)\nPY\n'
              'if [ "$swap_hup" = 1 ] && [ "$dpy_hup" = 1 ]; then')
    after = ('path.write_text(source)\nPY\n'
             'python3 "$self/daimos-k02-session-exec-v1729-hook.py" '
             '"$work/source/system/kernel"\n'
             'if [ "$swap_hup" = 1 ] && [ "$dpy_hup" = 1 ]; then')
    src = one(src, before, after)

    addresses = """for name in sess_fails sess_bad exec_fatal exec_nmem \
exec_postvm exec_failed exec_bad provcalls provrefuse leaseok leasebad \
foreign defer closefail fdclose syncall; do
    sym="daimos_"$name"_v1729"
    addr=$(awk -v s="$sym" '$1 == s {print $2; exit}' "$build/kcore.map")
    test -n "$addr" || { echo "v1729: missing $sym" >&2; exit 1; }
    printf '%s %s\\n' "$name" "$addr" >> "$work/addresses"
done
"""
    src = one(src, 'boot="$build/boot.ini"\n',
              addresses + 'boot="$build/boot.ini"\n')
    start = src.index('python3 - "$work/addresses" "$work/simh.out" '
                      '"$pipe_hup" "$dpy_hup"')
    src = src[:start] + r"""python3 - "$work/addresses" "$work/simh.out" <<'PY'
from pathlib import Path
import re
import sys

out = Path(sys.argv[2]).read_text(errors='replace')
seen = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    name, addr = line.split()
    values = re.findall(r'(?im)^\s*0*' + re.escape(addr.lstrip('0')) +
                        r'\s*:\s*([0-7]+)\b', out)
    if not values:
        raise SystemExit('v1729: missing counter ' + name +
                         '\n' + out[-1600:])
    seen[name] = int(values[-1], 8)

expected = dict(pins=1, unpins=0, failures=1, second=2,
                repeats=0, pending=0, errors=0,
                sess_fails=3, sess_bad=0, exec_fatal=1,
                exec_nmem=1, exec_postvm=1, exec_failed=1, exec_bad=0,
                leasebad=0, foreign=0, defer=0, closefail=0)
for name, expected_value in expected.items():
    if seen.get(name) != expected_value:
        raise SystemExit('v1729: ' + name + '=' + str(seen.get(name)) +
                         ' expected ' + str(expected_value) +
                         '\n' + out[-1750:])
if not (2 <= seen['provcalls'] <= 32 and
        seen['provcalls'] == seen['provrefuse'] ==
        seen['leaseok'] and seen['syncall'] >= seen['provcalls']):
    raise SystemExit('v1729: D6FS owner not permanently refused '
                     'under the real MRES lease:\n' + str(seen))
if (seen['leader'] != 2 or seen['first'] != 3 or
        seen['base'] == 0 or
        re.search(r'(?m)^<P\r?$', out) is None or
        'HALT' not in out or '!' in out):
    raise SystemExit('v1729: incomplete RUN/session/EXEC or parent '
                     'witness:\n' + out[-1800:])
print('K02 v1729: real session TTY retained across three D6FS '
      'refusals, independent VM_NONE fatal EXEC reaped PASS:', seen)
PY
"""
    (work / 'daimos-k02-session-exec-v1729.generated.sh').write_text(src)


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1729.py WORKDIR TESTKIT_VALIDATION_DIR')
    work = Path(sys.argv[1]).resolve()
    root = Path(sys.argv[2]).resolve()
    make_runner(root, work, make_guest(root, work))


if __name__ == '__main__':
    main()
