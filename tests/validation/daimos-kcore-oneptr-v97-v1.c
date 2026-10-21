/*
 * Focused 256K PDP-6 native-syscall test for KCORE single-pointer sharing.
 * Exercises all six services using real UUOs, including a failed VM mapping.
 * The target creates only versioned paths under /TEMP and removes them.
 */
#include "dsys.h"
#include "../test_sixbit.h"

static kword_t root_dir[] = {
        5UL, TEST_SIX6('/', 'T', 'E', 'M', 'P', ' ')
};
static kword_t test_dir[] = {
        10UL,
        TEST_SIX6('/', 'T', 'E', 'M', 'P', '/'),
        TEST_SIX6('V', '9', '7', 'D', ' ', ' ')
};
static kword_t test_file[] = {
        12UL,
        TEST_SIX6('/', 'T', 'E', 'M', 'P', '/'),
        TEST_SIX6('V', '9', '7', 'D', '/', 'F')
};

static void
mark(int ch)
{
        (void)dsys_writechar(1, ch);
}

static void
fail(int ch)
{
        mark('!');
        mark(ch);
        (void)dsys_exit(1);
}

int
main(void)
{
        struct sys_meminfo info;
        struct sys_procinfo pinfo;
        struct vfs_stat st;
        kword_t cwd[8];
        kword_t words[3];
        int fd;
        int pid;

        mark('<');
        if (dsys_meminfo(&info) != 0 || info.process_slots_used == 0UL ||
            info.resident_words == 0UL ||
            info.resident_words > info.total_words)
                fail('I');
        pid = dsys_getpid();
        if (pid < 0 || dsys_procinfo((unsigned int)pid, &pinfo) != 0 ||
            pinfo.pid != (kword_t)(unsigned int)pid || pinfo.state == 0UL)
                fail('J');
        if (dsys_mkdir(test_dir) != 0)
                fail('M');
        if (dsys_chdir(test_dir) != 0)
                fail('C');
        if (dsys_getcwd(cwd, 8U) != 0 || cwd[0] != 10UL ||
            cwd[1] != test_dir[1] || cwd[2] != test_dir[2])
                fail('G');

        fd = dsys_open(test_file, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 3)
                fail('O');
        words[0] = 0123456701234UL;
        words[1] = 0654321076543UL;
        words[2] = 0246135724613UL;
        if (dsys_write_words(fd, words, 3U) != 3 || dsys_close(fd) != 0)
                fail('W');
        if (dsys_truncate(test_file, 1UL) != 0 ||
            dsys_stat(test_file, &st) != 0 || st.size_words != 1UL)
                fail('T');
        if (dsys_unlink(test_file) != 0 ||
            dsys_stat(test_file, &st) == 0)
                fail('U');
        if (dsys_chdir(root_dir) != 0 || dsys_rmdir(test_dir) != 0)
                fail('R');

        /* A low user word cannot map; the syscall must fail and must
         * release its mapping hold so a valid subsequent call succeeds. */
        if (dsys_meminfo((struct sys_meminfo *)1UL) != -1 ||
            dsys_procinfo((unsigned int)pid,
                (struct sys_procinfo *)1UL) != -1 ||
            dsys_getcwd((kword_t *)1UL, 8U) != -1 ||
            dsys_meminfo(&info) != 0 ||
            dsys_procinfo((unsigned int)pid, &pinfo) != 0)
                fail('B');

        mark('P');
        (void)dsys_exit(0);
        return 0;
}
