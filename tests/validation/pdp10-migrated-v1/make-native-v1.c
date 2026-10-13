#include "dsys.h"
#include <pdp10-sixbit.h>

#define RUN_RECORD_WORDS 18U
#define RUN_BLOCK_WORDS \
    (SYS_RUN_V2_FIXED_WORDS + 6U * RUN_RECORD_WORDS + 2U)

static kword_t make_path[] = {
    17UL,
    PDP10_SIX6('/','S','Y','S','T','E'),
    PDP10_SIX6('M','/','E','X','E','C'),
    PDP10_SIX6('/','M','A','K','E',' ')
};

static kword_t make_name[] = {
    4UL,
    PDP10_SIX6('M','A','K','E',' ',' ')
};

static kword_t opt_f[] = {
    2UL,
    PDP10_SIX6('-','F',' ',' ',' ',' ')
};

static kword_t makefile_path[] = {
    14UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('M','A','K','E','F','I'),
    PDP10_SIX6('L','E',' ',' ',' ',' ')
};

static kword_t out_override[] = {
    13UL,
    PDP10_SIX6('O','U','T','=','/','T'),
    PDP10_SIX6('E','M','P','/','O','U'),
    PDP10_SIX6('T',' ',' ',' ',' ',' ')
};

static kword_t out_target[] = {
    9UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('O','U','T',' ',' ',' ')
};

static kword_t force_target[] = {
    5UL,
    PDP10_SIX6('F','O','R','C','E',' ')
};

static kword_t opt_n[] = {
    2UL,
    PDP10_SIX6('-','N',' ',' ',' ',' ')
};

static kword_t obj_target[] = {
    11UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('O','B','J','.','O',' ')
};

static kword_t src_path[] = {
    9UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('S','R','C',' ',' ',' ')
};

static kword_t phony_path[] = {
    11UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('P','H','O','N','Y',' ')
};

static kword_t objc_path[] = {
    11UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('O','B','J','.','C',' ')
};

static kword_t objo_path[] = {
    11UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('O','B','J','.','O',' ')
};

static unsigned int
record_words(const kword_t *record)
{
    unsigned int chars;

    chars = (unsigned int)(record[0] & 0777777UL);
    if (chars == 0U || chars > SYS_RUN_ARG_MAX_CHARS)
        return 0U;
    return 1U + (chars + 5U) / 6U;
}

static int
copy_record(kword_t *block, unsigned int *used, const kword_t *record)
{
    unsigned int words;
    unsigned int i;

    words = record_words(record);
    if (words == 0U || *used > RUN_BLOCK_WORDS - words)
        return -1;
    for (i = 0U; i < words; ++i)
        block[(*used)++] = record[i];
    return 0;
}

static int
run_make(kword_t **argv, unsigned int argc)
{
    kword_t block[RUN_BLOCK_WORDS];
    struct sys_run_v2 *run;
    kword_t status;
    unsigned int used;
    unsigned int i;
    int pid;

    used = SYS_RUN_V2_FIXED_WORDS;
    if (copy_record(block, &used, make_path) != 0)
        return -1;
    for (i = 0U; i < argc; ++i)
        if (copy_record(block, &used, argv[i]) != 0)
            return -1;
    if (used > RUN_BLOCK_WORDS - 2U)
        return -1;
    block[used++] = SYS_RUN_FD_MAP(1U, 1U);
    block[used++] = SYS_RUN_FD_MAP(2U, 2U);
    run = (struct sys_run_v2 *)block;
    run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2, used);
    run->flags = SYS_RUN_PGRP_INHERIT;
    run->pgrp = 0UL;
    run->fdmap_count = 2UL;
    run->argc = argc;
    run->envc = 0UL;
    pid = dsys_run(run);
    if (pid < 0)
        return -1;
    if (dsys_wait((unsigned int)pid, &status, 0U) != pid ||
        SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED)
        return -1;
    return (int)SYS_WAIT_STATUS_VALUE(status);
}

static void
put_text(const char *s)
{
    while (*s != 0) {
        (void)dsys_writechar(1, (int)(unsigned char)*s);
        ++s;
    }
}

static void
fail(char stage)
{
    put_text("MAKE NATIVE FAIL ");
    (void)dsys_writechar(1, stage);
    put_text("\r\n");
    (void)dsys_halt();
}

static kword_t
t36(unsigned int second)
{
    return ((kword_t)046U << 26U) | ((kword_t)1U << 22U) |
        ((kword_t)1U << 17U) | (kword_t)second;
}

static int
make_file(kword_t *path, kword_t when)
{
    kword_t word;
    int fd;

    word = 1UL;
    fd = dsys_open(path, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
    if (fd < 0 || dsys_write_words(fd, &word, 1U) != 1 ||
        dsys_close(fd) != 0 || dsys_utime(path, when) != 0)
        return -1;
    return 0;
}

int
main(void)
{
    kword_t *args[6];
    struct vfs_stat st;
    kword_t saved;
    int rc;

    if (make_file(src_path, t36(1U)) != 0 ||
        make_file(out_target, t36(2U)) != 0 ||
        make_file(objc_path, t36(1U)) != 0)
        fail('F');

    args[0] = make_name;
    args[1] = opt_f;
    args[2] = makefile_path;
    args[3] = out_override;
    args[4] = out_target;
    rc = run_make(args, 5U);
    if (rc != 0 || dsys_stat(out_target, &st) != 0 || st.mtime != t36(2U))
        fail('U');

    if (dsys_utime(src_path, t36(3U)) != 0)
        fail('T');
    rc = run_make(args, 5U);
    if (rc != 0 || dsys_stat(out_target, &st) != 0 || st.mtime == t36(2U))
        fail('R');

    args[3] = force_target;
    rc = run_make(args, 4U);
    if (rc != 0 || dsys_stat(phony_path, &st) != 0)
        fail('P');
    saved = st.mtime;
    if (dsys_utime(phony_path, t36(1U)) != 0)
        fail('V');
    rc = run_make(args, 4U);
    if (rc != 0 || dsys_stat(phony_path, &st) != 0 || st.mtime == t36(1U))
        fail('H');

    if (dsys_utime(phony_path, t36(1U)) != 0)
        fail('D');
    args[3] = opt_n;
    args[4] = force_target;
    rc = run_make(args, 5U);
    if (rc != 0 || dsys_stat(phony_path, &st) != 0 || st.mtime != t36(1U))
        fail('N');

    args[3] = obj_target;
    rc = run_make(args, 4U);
    if (rc != 0 || dsys_stat(objo_path, &st) != 0)
        fail('S');

    (void)saved;
    put_text("MAKE NATIVE PASS\r\n");
    (void)dsys_halt();
    return 0;
}
