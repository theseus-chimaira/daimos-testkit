#include "u.h"
#include "logstore.h"

#define TEST_BLOCKS 5U
#define TEST_CAPACITY 3U
#define MTC_REEL_MASK 0600000UL

extern int logdrain_program_main(int argc, kword_t **argv);
int __test_exit;

static kword_t media[TEST_BLOCKS][BLOCKSET_BLOCK_WORDS];
static kword_t argbuf[5][U_ARG_WORDS];
static kword_t *args[5];
static kword_t producer_next;
static unsigned int producer_slot;
static unsigned int console_chars;
static unsigned int file_writes;
static kword_t file_last_sequence;
static int file_exists;
static kword_t file_size_words;
static unsigned int rotate_count;
static kword_t tape_status;
static unsigned int tape_writes;
static kword_t tape_sequence;
static unsigned int tape_filemarks;
static unsigned int wait_calls;
static int wait_append_once;

static kword_t
rec_commit(kword_t sequence, unsigned int payload_words)
{
        kword_t v;
        v = (LOGSTORE_RECORD_MAGIC + sequence +
            ((kword_t)payload_words << 18)) & LOGSTORE_WORD_MASK;
        return (v ^ LOGSTORE_WORD_MASK) | 1UL;
}

static kword_t
state_commit(kword_t generation, kword_t next_sequence,
    kword_t lost, unsigned int capacity)
{
        kword_t v;
        v = (LOGSTORE_STATE_MAGIC + generation + next_sequence + lost +
            (kword_t)capacity) & LOGSTORE_WORD_MASK;
        return (v ^ LOGSTORE_WORD_MASK) | 1UL;
}

static void
clear_media(void)
{
        unsigned int i;
        unsigned int j;
        for (i = 0U; i < TEST_BLOCKS; ++i)
                for (j = 0U; j < BLOCKSET_BLOCK_WORDS; ++j)
                        media[i][j] = 0UL;
        producer_next = 1UL;
        producer_slot = 0U;
        console_chars = 0U;
        file_writes = 0U;
        file_last_sequence = 0UL;
        file_exists = 0;
        file_size_words = 0UL;
        rotate_count = 0U;
        tape_status = 0UL;
        tape_writes = 0U;
        tape_sequence = 0UL;
        tape_filemarks = 0U;
        wait_calls = 0U;
        wait_append_once = 0;
}

static void
make_record(unsigned int slot, kword_t seq, unsigned int sev)
{
        kword_t *b;
        unsigned int i;
        b = media[slot + 2U];
        for (i = 0U; i < BLOCKSET_BLOCK_WORDS; ++i)
                b[i] = 0UL;
        b[0] = LOGSTORE_RECORD_MAGIC;
        b[1] = seq;
        b[2] = seq + 0100UL;
        b[3] = ((kword_t)sev << 30);
        b[BLOCKSET_BLOCK_WORDS - 1U] = rec_commit(seq, 0U);
}

static void
append_record(unsigned int sev)
{
        make_record(producer_slot, producer_next, sev);
        ++producer_next;
        ++producer_slot;
        if (producer_slot >= TEST_CAPACITY)
                producer_slot = 0U;
}

static void
set_drain_state(unsigned int copy, kword_t generation,
    kword_t next_sequence, kword_t lost)
{
        kword_t *b;
        unsigned int i;
        b = media[copy];
        for (i = 0U; i < BLOCKSET_BLOCK_WORDS; ++i)
                b[i] = 0UL;
        b[0] = LOGSTORE_STATE_MAGIC;
        b[1] = generation;
        b[2] = next_sequence;
        b[3] = lost;
        b[4] = TEST_CAPACITY;
        b[BLOCKSET_BLOCK_WORDS - 1U] =
            state_commit(generation, next_sequence, lost, TEST_CAPACITY);
}

static int
best_state(kword_t *next, kword_t *lost)
{
        unsigned int c;
        unsigned int best;
        kword_t gen;
        best = 2U;
        gen = 0UL;
        for (c = 0U; c < 2U; ++c) {
                if (media[c][0] != LOGSTORE_STATE_MAGIC ||
                    media[c][1] == 0UL || media[c][4] != TEST_CAPACITY ||
                    media[c][BLOCKSET_BLOCK_WORDS - 1U] !=
                    state_commit(media[c][1], media[c][2], media[c][3],
                    TEST_CAPACITY))
                        continue;
                if (best == 2U || media[c][1] > gen) {
                        best = c;
                        gen = media[c][1];
                }
        }
        if (best == 2U)
                return -1;
        *next = media[best][2];
        *lost = media[best][3];
        return 0;
}

static int
make_args(const char *a0, const char *a1, const char *a2,
    const char *a3)
{
        const char *v[4];
        int argc;
        int i;
        v[0] = a0;
        v[1] = a1;
        v[2] = a2;
        v[3] = a3;
        argc = 0;
        for (i = 0; i < 4 && v[i] != 0; ++i) {
                if (u_s6_pack(argbuf[i], U_ARG_WORDS, v[i]) != 0)
                        return -1;
                args[i] = argbuf[i];
                ++argc;
        }
        return argc;
}

int
dsys_logctl(unsigned int op, kword_t arg, kword_t *buf)
{
        unsigned int i;
        if (op == SYS_LOGCTL_STATUS) {
                if (buf == 0) return -1;
                buf[0] = producer_next;
                buf[1] = ((kword_t)TEST_CAPACITY << 18) | producer_slot;
                buf[2] = TEST_BLOCKS;
                return 0;
        }
        if (op == SYS_LOGCTL_READ_BLOCK || op == SYS_LOGCTL_WRITE_BLOCK) {
                if (buf == 0 || arg >= TEST_BLOCKS) return -1;
                for (i = 0U; i < BLOCKSET_BLOCK_WORDS; ++i) {
                        if (op == SYS_LOGCTL_READ_BLOCK)
                                buf[i] = media[(unsigned int)arg][i];
                        else
                                media[(unsigned int)arg][i] = buf[i];
                }
                return 0;
        }
        if (op == SYS_LOGCTL_MTC_STATUS) {
                if (buf == 0 || arg > 7UL) return -1;
                *buf = tape_status;
                return 0;
        }
        if (op == SYS_LOGCTL_MTC_WRITE) {
                if (buf == 0 || arg > 7UL) return -1;
                ++tape_writes;
                tape_sequence = buf[1];
                return 0;
        }
        if (op == SYS_LOGCTL_MTC_FILEMARK) {
                ++tape_filemarks;
                return 0;
        }
        if (op == SYS_LOGCTL_WAIT) {
                ++wait_calls;
                if (wait_append_once != 0) {
                        wait_append_once = 0;
                        append_record(1U);
                        return 0;
                }
                return -1;
        }
        return -1;
}

int
dsys_mkdir(kword_t *p)
{
        (void)p;
        return 0;
}

int
dsys_stat(kword_t *p, struct vfs_stat *st)
{
        (void)p;
        if (!file_exists) return -1;
        st->type = VFS_TYPE_REG;
        st->size_words = file_size_words;
        return 0;
}

int
dsys_open(kword_t *p, unsigned int flags)
{
        (void)p;
        (void)flags;
        file_exists = 1;
        return 3;
}

int
dsys_close(int fd)
{
        return fd == 3 ? 0 : -1;
}

int
dsys_unlink(kword_t *p)
{
        (void)p;
        return 0;
}

int
dsys_rename(kword_t *a, kword_t *b)
{
        (void)a;
        (void)b;
        ++rotate_count;
        file_size_words = 0UL;
        return 0;
}

int
dsys_write_words(int fd, kword_t *b, unsigned int n, kword_t chars)
{
        if (fd != 3 || b == 0 || n != BLOCKSET_BLOCK_WORDS)
                return -1;
        ++file_writes;
        file_last_sequence = b[1];
        file_size_words += n;
        (void)chars;
        return (int)n;
}

int
dsys_writechar(int fd, int ch)
{
        (void)fd;
        (void)ch;
        ++console_chars;
        return 0;
}

int
dsys_write_chars(int fd, const char *b, unsigned int n)
{
        (void)fd;
        (void)b;
        console_chars += n;
        return 0;
}

static int
test_null_resume(void)
{
        int argc;
        kword_t next;
        kword_t lost;
        clear_media();
        append_record(1U);
        append_record(2U);
        argc = make_args("LOGDRAIN", "NULL", 0, 0);
        if (logdrain_program_main(argc, args) != 0 ||
            best_state(&next, &lost) != 0 || next != 3UL || lost != 0UL)
                return 1;
        append_record(3U);
        if (logdrain_program_main(argc, args) != 0 ||
            best_state(&next, &lost) != 0 || next != 4UL || lost != 0UL)
                return 2;
        return 0;
}

static int
test_loss(void)
{
        int argc;
        kword_t next;
        kword_t lost;
        clear_media();
        append_record(1U);
        append_record(1U);
        append_record(1U);
        append_record(1U);
        append_record(1U);
        set_drain_state(0U, 1UL, 1UL, 0UL);
        argc = make_args("LOGDRAIN", "NULL", 0, 0);
        if (logdrain_program_main(argc, args) != 0 ||
            best_state(&next, &lost) != 0 || next != 6UL || lost != 2UL)
                return 1;
        return 0;
}

static int
test_file(void)
{
        int argc;
        kword_t next;
        kword_t lost;
        clear_media();
        append_record(2U);
        argc = make_args("LOGDRAIN", "FILE", 0, 0);
        if (logdrain_program_main(argc, args) != 0 || file_writes != 1U ||
            file_last_sequence != 1UL || best_state(&next, &lost) != 0 ||
            next != 2UL)
                return 1;
        clear_media();
        append_record(2U);
        file_exists = 1;
        file_size_words = (kword_t)128U * BLOCKSET_BLOCK_WORDS;
        if (logdrain_program_main(argc, args) != 0 || rotate_count != 1U ||
            file_writes != 1U)
                return 2;
        return 0;
}

static int
test_console(void)
{
        int argc;
        unsigned int before;
        clear_media();
        append_record(3U);
        argc = make_args("LOGDRAIN", "CONSOLE", "4", 0);
        before = console_chars;
        if (logdrain_program_main(argc, args) != 0 ||
            console_chars != before)
                return 1;
        clear_media();
        append_record(4U);
        before = console_chars;
        if (logdrain_program_main(argc, args) != 0 ||
            console_chars <= before)
                return 2;
        return 0;
}

static int
test_mtc_reel(void)
{
        int argc;
        kword_t next;
        kword_t lost;
        clear_media();
        append_record(2U);
        argc = make_args("LOGDRAIN", "MTC", "0", 0);
        tape_status = MTC_REEL_MASK;
        if (logdrain_program_main(argc, args) != 2 || tape_writes != 0U ||
            best_state(&next, &lost) == 0)
                return 1;
        tape_status = 0UL;
        if (logdrain_program_main(argc, args) != 0 || tape_writes != 1U ||
            tape_sequence != 1UL || tape_filemarks != 1U ||
            best_state(&next, &lost) != 0 || next != 2UL)
                return 2;
        return 0;
}

static int
test_follow(void)
{
        int argc;
        kword_t next;
        kword_t lost;
        clear_media();
        argc = make_args("LOGDRAIN", "FOLLOW", "NULL", 0);
        wait_append_once = 1;
        if (logdrain_program_main(argc, args) != 1 || wait_calls != 2U ||
            best_state(&next, &lost) != 0 || next != 2UL)
                return 1;
        return 0;
}

int
main(void)
{
        int rc;
        rc = test_null_resume();
        if (rc != 0) return 10 + rc;
        rc = test_loss();
        if (rc != 0) return 20 + rc;
        rc = test_file();
        if (rc != 0) return 30 + rc;
        rc = test_console();
        if (rc != 0) return 40 + rc;
        rc = test_mtc_reel();
        if (rc != 0) return 50 + rc;
        rc = test_follow();
        if (rc != 0) return 60 + rc;
        return 0;
}
