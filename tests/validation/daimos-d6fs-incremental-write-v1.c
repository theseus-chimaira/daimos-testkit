#include "u.h"

static kword_t path[U_PATH_WORDS];
static kword_t source_path[U_PATH_WORDS];
static kword_t scratch_path[3][U_PATH_WORDS];
static kword_t cwd_path[U_PATH_WORDS];

struct probe_wordfile {
        int fd;
        unsigned int words;
};

static int
probe_wordfile_write(struct probe_wordfile *wf, const kword_t *words,
    unsigned int count)
{
        while (count != 0U) {
                int rc;

                rc = dsys_write_words(wf->fd, (kword_t *)words, count);
                if (rc <= 0)
                        return -1;
                words += (unsigned int)rc;
                count -= (unsigned int)rc;
        }
        return 0;
}

static int
probe_wordfile_append(struct probe_wordfile *wf, const kword_t *words,
    unsigned int count)
{
        if (dsys_seek(wf->fd, (kword_t)wf->words, SYS_SEEK_SET) ==
            (kword_t)-1 || probe_wordfile_write(wf, words, count) != 0)
                return -1;
        wf->words += count;
        return 0;
}

static int
fail(const char *stage, int rc)
{
        (void)u_puts(2, "D6FS-INCREMENTAL-FAIL ");
        (void)u_puts(2, stage);
        (void)u_puts(2, " RC=");
        (void)u_put_octal(2, (kword_t)rc, 12U);
        (void)u_crlf(2);
        return 1;
}

static int
fail_word(unsigned int index, kword_t got, kword_t want)
{
        (void)u_puts(2, "D6FS-INCREMENTAL-WORD ");
        (void)u_put_octal(2, (kword_t)index, 2U);
        (void)u_puts(2, " GOT=");
        (void)u_put_octal(2, got, 12U);
        (void)u_puts(2, " WANT=");
        (void)u_put_octal(2, want, 12U);
        (void)u_crlf(2);
        return 1;
}

int
main(int argc, kword_t **argv)
{
        struct vfs_stat st;
        kword_t in[4];
        kword_t out[4];
        kword_t source_buf[16];
        kword_t header;
        struct probe_wordfile wf;
        int scratch_fd[3];
        int source_fd;
        int fd;
        int rc;

        (void)argc;
        (void)argv;
        if (u_s6_pack(cwd_path, U_PATH_WORDS,
            "/OPTION/BASE/SOURCE/ASMUTILS") != 0 ||
            dsys_chdir(cwd_path) != 0 ||
            u_s6_pack(scratch_path[0], U_PATH_WORDS, "PROBE.DSY") != 0 ||
            u_s6_pack(scratch_path[1], U_PATH_WORDS, "PROBE.DLT") != 0 ||
            u_s6_pack(scratch_path[2], U_PATH_WORDS, "PROBE.DRP") != 0 ||
            u_s6_pack(path, U_PATH_WORDS, "PROBE.D1R") != 0)
                return fail("PACK", -1);
        for (rc = 0; rc < 3; ++rc) {
                scratch_fd[rc] = dsys_open(scratch_path[rc],
                    SYS_O_RDWR | SYS_O_CREAT | SYS_O_TRUNC);
                if (scratch_fd[rc] < 0)
                        return fail("SCRATCH-OPEN", scratch_fd[rc]);
        }
        fd = dsys_open(path, SYS_O_RDWR | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
                return fail("OPEN", fd);
        in[0] = 0123456701234UL;
        in[1] = 0765432107654UL;
        in[2] = 0111111222222UL;
        in[3] = 0333333444444UL;
        wf.fd = fd;
        wf.words = 0U;
        header = in[0];
        if (probe_wordfile_append(&wf, &header, 1U) != 0)
                return fail("WRITE1-CHAIN", -1);
        /* D6FS providers share one transfer workspace.  Native DAS writes a
         * scratch word, reads source text, then resumes the scratch stream;
         * preserve that exact interleaving in the regression. */
        if (u_s6_pack(source_path, U_PATH_WORDS, "ARGS.S") != 0)
                return fail("SOURCE-PACK", -1);
        source_fd = dsys_open(source_path, SYS_O_RDONLY);
        if (source_fd < 0)
                return fail("SOURCE-OPEN", source_fd);
        rc = dsys_read_words(source_fd, source_buf, 16U);
        if (rc <= 0)
                return fail("SOURCE-READ", rc);
        if (dsys_seek(fd, 1UL, SYS_SEEK_SET) != 1UL)
                return fail("SEEK1", -1);
        rc = dsys_write_words(fd, &in[1], 1U);
        if (rc != 1)
                return fail("WRITE2", rc);
        rc = dsys_write_words(fd, &in[2], 2U);
        if (rc != 2)
                return fail("WRITE3", rc);
        (void)dsys_close(source_fd);
        for (rc = 0; rc < 3; ++rc)
                (void)dsys_close(scratch_fd[rc]);
        if (dsys_close(fd) != 0)
                return fail("CLOSE", -1);
        if (dsys_stat(path, &st) != 0 || st.size_words != 4UL)
                return fail("STAT", -1);
        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0)
                return fail("REOPEN", fd);
        out[0] = out[1] = out[2] = out[3] = 0UL;
        rc = dsys_read_words(fd, out, 4U);
        (void)dsys_close(fd);
        if (rc != 4)
                return fail("VERIFY", rc);
        for (rc = 0; rc < 4; ++rc)
                if (out[rc] != in[rc])
                        return fail_word((unsigned int)rc, out[rc], in[rc]);
        {
                static const char pass[] = "D6FS-INCREMENTAL-PASS\r\n";
                unsigned int pi;

                for (pi = 0U; pass[pi] != 0; ++pi)
                        if (dsys_writechar(1, pass[pi]) < 0)
                                return 1;
        }
        return 0;
}
