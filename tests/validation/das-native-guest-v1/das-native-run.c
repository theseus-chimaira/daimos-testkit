#include "dsys.h"
#include <pdp10-sixbit.h>

#define RUN_RECORD_WORDS 18U
#define RUN_BLOCK_WORDS \
    (SYS_RUN_V2_FIXED_WORDS + 7U * RUN_RECORD_WORDS + 2U)

static kword_t das_path[] = {
    21UL,
    PDP10_SIX6('/','O','P','T','I','O'),
    PDP10_SIX6('N','/','B','A','S','E'),
    PDP10_SIX6('/','E','X','E','C','/'),
    PDP10_SIX6('D','A','S',' ',' ',' ')
};

static kword_t das_name[] = {
    3UL,
    PDP10_SIX6('D','A','S',' ',' ',' ')
};

static kword_t opt_f[] = {
    2UL,
    PDP10_SIX6('-','F',' ',' ',' ',' ')
};

static kword_t opt_o[] = {
    2UL,
    PDP10_SIX6('-','O',' ',' ',' ',' ')
};

static kword_t output_path[] = {
    13UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('O','U','T','.','D','X'),
    PDP10_SIX6('R',' ',' ',' ',' ',' ')
};

static kword_t source_path[] = {
    12UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('T','E','S','T','.','S')
};

/* Check the writable scratch directory before invoking either DAS phase.
 * A failed OPEN is a filesystem/guest setup error, not a parser failure. */
static kword_t scratch_probe_path[] = {
    17UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('O','U','T','.','D','X'),
    PDP10_SIX6('R','.','D','2','R',' ')
};

static kword_t temp_dir_path[] = {
    5UL,
    PDP10_SIX6('/','T','E','M','P',' ')
};

static kword_t short_probe_path[] = {
    7UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('P',' ',' ',' ',' ',' ')
};

static kword_t dir_probe_path[] = {
    7UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('Z',' ',' ',' ',' ',' ')
};

static kword_t out_name[] = {
    3UL,
    PDP10_SIX6('O','U','T',' ',' ',' ')
};

static const kword_t expected_image[] = {
    0447062000000UL,
    0000003000000UL,
    0201040000000UL,
    0040001000000UL,
    0254200000002UL,
    0100000000000UL
};

static unsigned int
record_words(const kword_t *record)
{
    unsigned int chars;

    if (record == 0)
        return 0U;
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
run_child(const kword_t *path, kword_t **argv, unsigned int argc,
    int map_output)
{
    kword_t block[RUN_BLOCK_WORDS];
    struct sys_run_v2 *run;
    kword_t status;
    unsigned int used;
    unsigned int i;
    int pid;

    if (argc == 0U || argc > SYS_RUN_ARG_MAX)
        return -1;
    used = SYS_RUN_V2_FIXED_WORDS;
    if (copy_record(block, &used, path) != 0)
        return -1;
    for (i = 0U; i < argc; ++i) {
        if (copy_record(block, &used, argv[i]) != 0)
            return -1;
    }
    if (map_output) {
        if (used > RUN_BLOCK_WORDS - 2U)
            return -1;
        block[used++] = SYS_RUN_FD_MAP(1U, 1U);
        block[used++] = SYS_RUN_FD_MAP(2U, 2U);
    }

    run = (struct sys_run_v2 *)block;
    run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2, used);
    run->flags = SYS_RUN_PGRP_INHERIT;
    run->pgrp = 0UL;
    run->fdmap_count = map_output ? 2UL : 0UL;
    run->argc = (kword_t)argc;
    run->envc = 0UL;
    pid = dsys_run(run);
    if (pid < 0)
        return -1;
    status = 0UL;
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
put_octal(kword_t value)
{
    unsigned int shift;

    shift = 33U;
    for (;;) {
        (void)dsys_writechar(1,
            (int)('0' + ((value >> shift) & 07UL)));
        if (shift == 0U)
            break;
        shift -= 3U;
    }
}

static void
fail(char stage)
{
    put_text("DAS NATIVE FAIL ");
    (void)dsys_writechar(1, stage);
    (void)dsys_writechar(1, '\r');
    (void)dsys_writechar(1, '\n');
    (void)dsys_halt();
}

int
main(void)
{
    kword_t *das_argv[5];
    kword_t *out_argv[1];
    kword_t words[6];
    struct vfs_stat st;
    struct sys_fsinfo root_info;
    unsigned int i;
    int fd;
    int rc;

    das_argv[0] = das_name;
    if (dsys_stat(temp_dir_path, &st) != 0)
        fail('D');
    put_text("DAS TEMP MODE ");
    put_octal((kword_t)st.mode);
    put_text("\r\n");
    if (dsys_stat(source_path, &st) != 0)
        fail('I');
    if (dsys_fsinfo(0U, &root_info) != 1)
        fail('F');
    put_text("DAS ROOT FLAGS ");
    put_octal(root_info.flags);
    put_text("\r\n");
    fd = dsys_open(source_path, SYS_O_WRONLY);
    if (fd < 0)
        fail('B');
    if (dsys_close(fd) != 0)
        fail('C');
    rc = dsys_chmod(source_path, 0644U);
    put_text("DAS EXISTING CHMOD ");
    put_octal((kword_t)(unsigned int)rc);
    put_text("\r\n");
    if (rc != 0)
        fail('H');
    rc = dsys_mkdir(dir_probe_path);
    put_text("DAS NEW MKDIR ");
    put_octal((kword_t)(unsigned int)rc);
    put_text("\r\n");
    if (rc != 0)
        fail('N');
    if (dsys_rmdir(dir_probe_path) != 0)
        fail('Z');
    fd = dsys_open(short_probe_path,
        SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
    if (fd < 0)
        fail('W');
    if (dsys_close(fd) != 0 || dsys_unlink(short_probe_path) != 0)
        fail('V');
    fd = dsys_open(scratch_probe_path,
        SYS_O_RDWR | SYS_O_CREAT | SYS_O_TRUNC);
    if (fd < 0)
        fail('P');
    if (dsys_close(fd) != 0 || dsys_unlink(scratch_probe_path) != 0)
        fail('Q');
    das_argv[1] = opt_f;
    das_argv[2] = opt_o;
    das_argv[3] = output_path;
    das_argv[4] = source_path;
    rc = run_child(das_path, das_argv, 5U, 1);
    if (rc != 0) {
        put_text("DAS STATUS ");
        put_octal((kword_t)(unsigned int)rc);
        put_text("\r\n");
        fail('A');
    }
    if (dsys_stat(output_path, &st) != 0 || st.size_words != 6UL)
        fail('S');
    fd = dsys_open(output_path, SYS_O_RDONLY);
    if (fd < 0 || dsys_read_words(fd, words, 6U) != 6 ||
        dsys_close(fd) != 0)
        fail('R');
    for (i = 0U; i < 6U; ++i) {
        if (words[i] != expected_image[i]) {
            put_text("DAS WORD ");
            (void)dsys_writechar(1, (int)('0' + i));
            (void)dsys_writechar(1, ' ');
            put_octal(words[i]);
            put_text(" EXPECT ");
            put_octal(expected_image[i]);
            (void)dsys_writechar(1, '\r');
            (void)dsys_writechar(1, '\n');
            fail('E');
        }
    }
    if (dsys_chmod(output_path, 0555U) != 0)
        fail('M');

    out_argv[0] = out_name;
    rc = run_child(output_path, out_argv, 1U, 0);
    if (rc != 0)
        fail('X');

    put_text("DAS NATIVE PASS\r\n");
    (void)dsys_halt();
    return 0;
}
