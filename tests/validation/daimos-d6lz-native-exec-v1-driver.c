#include "u.h"
#include "exec.h"

static kword_t path_d6lz[U_PATH_WORDS];
static kword_t path_source[U_PATH_WORDS];
static kword_t path_output[U_PATH_WORDS];
static kword_t arg_x[U_ARG_WORDS];

static unsigned int
record_words(const kword_t *record)
{
        return 1U + ((unsigned int)record[0] + 5U) / 6U;
}

static int
copy_record(kword_t *dst, unsigned int *pos, const kword_t *src,
    unsigned int cap)
{
        unsigned int i;
        unsigned int n;

        n = record_words(src);
        if (*pos + n > cap) return -1;
        for (i = 0U; i < n; ++i) dst[(*pos)++] = src[i];
        return 0;
}

static int
run_wait(const kword_t *path, unsigned int argc, kword_t **argv)
{
        kword_t block[SYS_RUN_V2_FIXED_WORDS + 5U * U_PATH_WORDS + 3U];
        struct sys_run_v2 *run;
        kword_t status;
        unsigned int total;
        unsigned int i;
        int pid;

        total = SYS_RUN_V2_FIXED_WORDS;
        if (copy_record(block, &total, path,
            (unsigned int)(sizeof(block) / sizeof(block[0]))) != 0)
                return -1;
        for (i = 0U; i < argc; ++i)
                if (copy_record(block, &total, argv[i],
                    (unsigned int)(sizeof(block) / sizeof(block[0]))) != 0)
                        return -1;
        if (total + 3U > (unsigned int)(sizeof(block) / sizeof(block[0])))
                return -1;
        block[total++] = SYS_RUN_FD_MAP(0U, 0U);
        block[total++] = SYS_RUN_FD_MAP(1U, 1U);
        block[total++] = SYS_RUN_FD_MAP(2U, 2U);
        run = (struct sys_run_v2 *)block;
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2, total);
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->pgrp = 0;
        run->fdmap_count = 3U;
        run->argc = argc;
        run->envc = 0;
        pid = dsys_run(run);
        if (pid < 0 || dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED)
                return -1;
        return (int)SYS_WAIT_STATUS_VALUE(status);
}

int
main(void)
{
        kword_t *compress_argv[4];
        kword_t *run_argv[1];

        if (u_s6_pack(path_d6lz, U_PATH_WORDS, "/SYSTEM/EXEC/D6LZ") != 0 ||
            u_s6_pack(path_source, U_PATH_WORDS,
            "/SYSTEM/EXEC/TSFSPROBE") != 0 ||
            u_s6_pack(path_output, U_PATH_WORDS, "/TEMP/CEXEC") != 0 ||
            u_s6_pack(arg_x, U_ARG_WORDS, "-X") != 0)
                return 1;
        compress_argv[0] = path_d6lz;
        compress_argv[1] = arg_x;
        compress_argv[2] = path_source;
        compress_argv[3] = path_output;
        (void)u_puts(1, "D6LZ-DRIVER-A");
        (void)u_crlf(1);
        {
                int child_rc;
                child_rc = run_wait(path_d6lz, 4U, compress_argv);
                if (child_rc != 0) {
                        (void)u_puts(1, "D6LZ-DRIVER-COMPRESS-RC ");
                        (void)u_put_uint(1, (kword_t)(unsigned int)child_rc);
                        (void)u_crlf(1);
                        return 2;
                }
        }
        (void)u_puts(1, "D6LZ-DRIVER-B");
        (void)u_crlf(1);
        {
                struct vfs_stat st;
                kword_t hdr[3];
                int fd;
                int nr;
                if (dsys_stat(path_output, &st) != 0) {
                        (void)u_puts(1, "D6LZ-STAT-FAIL");
                        (void)u_crlf(1);
                        return 5;
                }
                (void)u_puts(1, "D6LZ-OUT-MODE ");
                (void)u_put_octal(1, (kword_t)st.mode, 6U);
                (void)u_puts(1, " WORDS ");
                (void)u_put_uint(1, st.size_words);
                (void)u_crlf(1);
                fd = dsys_open(path_output, SYS_O_RDONLY);
                if (fd < 0) return 6;
                nr = dsys_read_words(fd, hdr, 3U);
                (void)dsys_close(fd);
                if (nr != 3) return 7;
                if ((hdr[1] & EXEC_DXR_F_COMPRESSED) == 0U) return 10;
                (void)u_puts(1, "D6LZ-HDR0 ");
                (void)u_put_octal(1, hdr[0], 12U);
                (void)u_puts(1, " HDR1 ");
                (void)u_put_octal(1, hdr[1], 12U);
                (void)u_puts(1, " HDR2 ");
                (void)u_put_octal(1, hdr[2], 12U);
                (void)u_crlf(1);
                {
                        kword_t buf[32];
                        kword_t x;
                        kword_t sum;
                        int n;
                        unsigned int i;
                        x = 0;
                        sum = 0;
                        fd = dsys_open(path_output, SYS_O_RDONLY);
                        if (fd < 0) return 8;
                        for (;;) {
                                n = dsys_read_words(fd, buf, 32U);
                                if (n < 0) { (void)dsys_close(fd); return 9; }
                                if (n == 0) break;
                                for (i = 0U; i < (unsigned int)n; ++i) {
                                        x ^= buf[i];
                                        sum = (sum + buf[i]) & 0777777777777UL;
                                }
                        }
                        (void)dsys_close(fd);
                        (void)u_puts(1, "D6LZ-XOR ");
                        (void)u_put_octal(1, x, 12U);
                        (void)u_puts(1, " SUM ");
                        (void)u_put_octal(1, sum, 12U);
                        (void)u_crlf(1);
                }
        }
        run_argv[0] = path_output;
        {
                int child_rc;
                child_rc = run_wait(path_output, 1U, run_argv);
                if (child_rc != 0) {
                        (void)u_puts(1, "D6LZ-DRIVER-EXEC-RC ");
                        (void)u_put_uint(1, (kword_t)(unsigned int)child_rc);
                        (void)u_crlf(1);
                        return 3;
                }
        }
        if (u_puts(1, "D6LZ-NATIVE-EXEC-PASS") != 0 || u_crlf(1) != 0)
                return 4;
        return 0;
}
