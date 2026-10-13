#include "dsys.h"
#include <pdp10-sixbit.h>

#define RUN_RECORD_WORDS 18U
#define RUN_BLOCK_WORDS \
    (SYS_RUN_V2_FIXED_WORDS + 3U * RUN_RECORD_WORDS + 2U)

static kword_t dsh_path[] = {
    16UL,
    PDP10_SIX6('/','S','Y','S','T','E'),
    PDP10_SIX6('M','/','E','X','E','C'),
    PDP10_SIX6('/','D','S','H',' ',' ')
};

static kword_t dsh_name[] = {
    3UL,
    PDP10_SIX6('D','S','H',' ',' ',' ')
};

static kword_t script_path[] = {
    23UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('A','S','M','U','T','I'),
    PDP10_SIX6('L','S','/','T','E','S'),
    PDP10_SIX6('T','.','D','S','H',' ')
};

static kword_t grow_path[] = {
    10UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('G','R','O','W',' ',' ')
};

static kword_t grow2_path[] = {
    11UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('G','R','O','W','2',' ')
};

static kword_t asm_grow_path[] = {
    19UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('A','S','M','U','T','I'),
    PDP10_SIX6('L','S','/','G','R','O'),
    PDP10_SIX6('W',' ',' ',' ',' ',' ')
};

static kword_t scratch_paths[5][4] = {
    {17UL, PDP10_SIX6('/','T','E','M','P','/'), PDP10_SIX6('A','S','M','U','T','I'), PDP10_SIX6('L','S','/','S','0',' ')},
    {17UL, PDP10_SIX6('/','T','E','M','P','/'), PDP10_SIX6('A','S','M','U','T','I'), PDP10_SIX6('L','S','/','S','1',' ')},
    {17UL, PDP10_SIX6('/','T','E','M','P','/'), PDP10_SIX6('A','S','M','U','T','I'), PDP10_SIX6('L','S','/','S','2',' ')},
    {17UL, PDP10_SIX6('/','T','E','M','P','/'), PDP10_SIX6('A','S','M','U','T','I'), PDP10_SIX6('L','S','/','S','3',' ')},
    {17UL, PDP10_SIX6('/','T','E','M','P','/'), PDP10_SIX6('A','S','M','U','T','I'), PDP10_SIX6('L','S','/','S','4',' ')}
};

static kword_t args_source_path[] = {
    21UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('A','S','M','U','T','I'),
    PDP10_SIX6('L','S','/','A','R','G'),
    PDP10_SIX6('S','.','S',' ',' ',' ')
};

static kword_t grow_words[03000];
static kword_t check_words[03000];

static unsigned int
record_words(const kword_t *record)
{
    unsigned int chars;

    chars = (unsigned int)(record[0] & 0777777UL);
    return 1U + (chars + 5U) / 6U;
}

static int
append_record(kword_t *block, unsigned int *used, const kword_t *record)
{
    unsigned int words;
    unsigned int i;

    words = record_words(record);
    if (*used + words > RUN_BLOCK_WORDS)
        return -1;
    for (i = 0U; i < words; ++i)
        block[(*used)++] = record[i];
    return 0;
}

static void
put_text(const char *s)
{
    while (*s != 0) {
        (void)dsys_writechar(1, (int)(unsigned char)*s);
        ++s;
    }
}

int
main(void)
{
    kword_t block[RUN_BLOCK_WORDS];
    struct sys_run_v2 *run;
    kword_t status;
    unsigned int used;
    unsigned int i;
    int fd;
    int pid;

#ifdef ASMUTILS_SCRATCH_PROBE
    {
        int fds[5];
        int srcfd;
        kword_t one;
        kword_t payload[15];
        kword_t input[32];

        one = 0123456701234UL;
        for (i = 0U; i < 15U; ++i)
            payload[i] = (kword_t)(0100000U + i);
        for (i = 0U; i < 5U; ++i) {
            fds[i] = dsys_open(scratch_paths[i],
                SYS_O_RDWR | SYS_O_CREAT | SYS_O_TRUNC);
            if (fds[i] < 0) {
                put_text("ASMUTILS SCRATCH OPEN FAIL\r\n");
                (void)dsys_halt();
            }
        }
        if (dsys_seek(fds[4], 0U, SYS_SEEK_SET) != 0U) {
            put_text("ASMUTILS SCRATCH SEEK FAIL\r\n");
            (void)dsys_halt();
        }
        if (dsys_write_words(fds[4], &one, 1U) != 1) {
            put_text("ASMUTILS SCRATCH MAGIC FAIL\r\n");
            (void)dsys_halt();
        }
        srcfd = dsys_open(args_source_path, SYS_O_RDONLY);
        if (srcfd < 0 || dsys_read_words(srcfd, input, 32U) != 32) {
            put_text("ASMUTILS SCRATCH READ FAIL\r\n");
            (void)dsys_halt();
        }
        if (dsys_seek(fds[4], 1U, SYS_SEEK_SET) != 1U) {
            put_text("ASMUTILS SCRATCH APPEND SEEK FAIL\r\n");
            (void)dsys_halt();
        }
        if (dsys_write_words(fds[4], &one, 1U) != 1) {
            put_text("ASMUTILS SCRATCH HEADER FAIL\r\n");
            (void)dsys_halt();
        }
        if (dsys_write_words(fds[4], payload, 15U) != 15) {
            put_text("ASMUTILS SCRATCH PAYLOAD FAIL\r\n");
            (void)dsys_halt();
        }
        for (i = 0U; i < 5U; ++i)
            if (dsys_close(fds[i]) != 0) {
                put_text("ASMUTILS SCRATCH CLOSE FAIL\r\n");
                (void)dsys_halt();
            }
        if (dsys_close(srcfd) != 0) {
            put_text("ASMUTILS SCRATCH SOURCE CLOSE FAIL\r\n");
            (void)dsys_halt();
        }
        put_text("ASMUTILS SCRATCH PASS\r\n");
        (void)dsys_halt();
    }
#endif

#ifndef ASMUTILS_SKIP_STORAGE_PRELUDE
    for (i = 0U; i < 03000U; ++i)
        grow_words[i] = (kword_t)i;
    fd = dsys_open(grow_path, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
    if (fd < 0 || dsys_write_words(fd, grow_words, 01000U) != 01000 ||
        dsys_close(fd) != 0) {
        put_text("ASMUTILS NATIVE FAIL G\r\n");
        (void)dsys_halt();
    }
    fd = dsys_open(grow2_path, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
    if (fd < 0 || dsys_write_words(fd, grow_words, 01000U) != 01000 ||
        dsys_close(fd) != 0) {
        put_text("ASMUTILS NATIVE FAIL J\r\n");
        (void)dsys_halt();
    }
    fd = dsys_open(grow2_path, SYS_O_RDWR | SYS_O_CREAT | SYS_O_TRUNC);
    if (fd < 0 || dsys_close(fd) != 0) {
        put_text("ASMUTILS NATIVE FAIL X\r\n");
        (void)dsys_halt();
    }
    {
        struct vfs_stat st;

        if (dsys_stat(grow2_path, &st) != 0 || st.size_words != 0UL) {
            put_text("ASMUTILS NATIVE FAIL Z\r\n");
            (void)dsys_halt();
        }
    }
    fd = dsys_open(grow2_path, SYS_O_RDWR);
    if (fd < 0) {
        put_text("ASMUTILS NATIVE FAIL Y0\r\n");
        (void)dsys_halt();
    }
    {
        int wr;

        wr = dsys_write_words(fd, grow_words, 2U);
        if (wr != 2) {
            if (wr == 070) put_text("ASMUTILS NATIVE FAIL YA\r\n");
            else if (wr == 071) put_text("ASMUTILS NATIVE FAIL YZ\r\n");
            else if (wr == 072) put_text("ASMUTILS NATIVE FAIL YM\r\n");
            else if (wr == 073) put_text("ASMUTILS NATIVE FAIL YR\r\n");
            else if (wr == 074) put_text("ASMUTILS NATIVE FAIL YW\r\n");
            else if (wr == 075) put_text("ASMUTILS NATIVE FAIL YF\r\n");
            else if (wr == 076) put_text("ASMUTILS NATIVE FAIL YP\r\n");
            else if (wr == 077) put_text("ASMUTILS NATIVE FAIL YD\r\n");
            else if (wr == 0100) put_text("ASMUTILS NATIVE FAIL YV\r\n");
            else if (wr == 0101) put_text("ASMUTILS NATIVE FAIL YT\r\n");
            if (wr == -2) put_text("ASMUTILS NATIVE FAIL Y2\r\n");
            else if (wr == -3) put_text("ASMUTILS NATIVE FAIL Y3\r\n");
            else if (wr == -4) put_text("ASMUTILS NATIVE FAIL Y4\r\n");
            else if (wr != 070 && wr != 071 && wr != 072 && wr != 073 &&
                wr != 074 && wr != 075 && wr != 076 && wr != 077 &&
                wr != 0100 && wr != 0101)
                put_text("ASMUTILS NATIVE FAIL Y1\r\n");
            (void)dsys_halt();
        }
    }
    if (dsys_close(fd) != 0) {
        put_text("ASMUTILS NATIVE FAIL YC\r\n");
        (void)dsys_halt();
    }
    fd = dsys_open(grow_path, SYS_O_RDWR);
    if (fd < 0 || dsys_seek(fd, 01000U, SYS_SEEK_SET) != 01000U ||
        dsys_write_words(fd, grow_words + 01000U, 02000U) != 02000 ||
        dsys_seek(fd, 0U, SYS_SEEK_SET) != 0U ||
        dsys_read_words(fd, check_words, 03000U) != 03000 ||
        dsys_close(fd) != 0) {
        put_text("ASMUTILS NATIVE FAIL M\r\n");
        (void)dsys_halt();
    }
    for (i = 0U; i < 03000U; ++i) {
        if (check_words[i] != grow_words[i]) {
            put_text("ASMUTILS NATIVE FAIL Q\r\n");
            (void)dsys_halt();
        }
    }
    fd = dsys_open(grow_path, SYS_O_RDWR | SYS_O_TRUNC);
    if (fd < 0 || dsys_close(fd) != 0) {
        put_text("ASMUTILS NATIVE FAIL XT\r\n");
        (void)dsys_halt();
    }
    {
        struct vfs_stat st;

        if (dsys_stat(grow_path, &st) != 0 || st.size_words != 0UL) {
            put_text("ASMUTILS NATIVE FAIL XZ\r\n");
            (void)dsys_halt();
        }
    }
#endif

    used = SYS_RUN_V2_FIXED_WORDS;
    if (append_record(block, &used, dsh_path) != 0 ||
        append_record(block, &used, dsh_name) != 0 ||
        append_record(block, &used, script_path) != 0 ||
        used + 2U > RUN_BLOCK_WORDS) {
        put_text("ASMUTILS NATIVE FAIL B\r\n");
        (void)dsys_halt();
    }
    block[used++] = SYS_RUN_FD_MAP(1U, 1U);
    block[used++] = SYS_RUN_FD_MAP(2U, 2U);
    run = (struct sys_run_v2 *)block;
    run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2, used);
    run->flags = SYS_RUN_PGRP_INHERIT;
    run->pgrp = 0UL;
    run->fdmap_count = 2UL;
    run->argc = 2UL;
    run->envc = 0UL;
    pid = dsys_run(run);
    if (pid < 0 || dsys_wait((unsigned int)pid, &status, 0U) != pid ||
        SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
        SYS_WAIT_STATUS_VALUE(status) != 0U) {
        put_text("ASMUTILS NATIVE FAIL R\r\n");
        (void)dsys_halt();
    }
    put_text("ASMUTILS NATIVE PASS\r\n");
    (void)dsys_halt();
    return 0;
}
