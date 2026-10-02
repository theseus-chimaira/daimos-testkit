#include "logstore.h"
#include "blockset_boot.h"
#include "storage.h"

#define TEST_BLOCKS 5U

static kword_t media[TEST_BLOCKS][BLOCKSET_BLOCK_WORDS];
static int fail_block = -1;
static unsigned int fail_words;
static unsigned int writes;
static int tape_status = MTC_ST_TAPE_FREE;
static int tape_fail;
static unsigned int tape_writes;
static kword_t tape_sequence;
static unsigned int tape_unit;
int __test_exit;

int
logstore_tape_io(unsigned int unit, int op, kword_t *block,
    unsigned int words)
{
        if (unit != tape_unit)
                return -1;
        if (op == MTC_OP_STATUS)
                return tape_status;
        if (op != MTC_OP_WRITE || block == 0 ||
            words != BLOCKSET_BLOCK_WORDS)
                return -1;
        ++tape_writes;
        tape_sequence = block[1];
        if (tape_fail != 0) {
                tape_fail = 0;
                return -5;
        }
        return 0;
}

kword_t
logstore_boot_blocks(void)
{
        return TEST_BLOCKS;
}

int
logstore_boot_read(kword_t blockno, kword_t block[BLOCKSET_BLOCK_WORDS])
{
        unsigned int i;

        if (blockno >= TEST_BLOCKS || block == 0)
                return -1;
        for (i = 0U; i < BLOCKSET_BLOCK_WORDS; ++i)
                block[i] = media[(unsigned int)blockno][i];
        return 0;
}

int
logstore_boot_write(kword_t blockno,
    const kword_t block[BLOCKSET_BLOCK_WORDS])
{
        unsigned int i;
        unsigned int n;

        if (blockno >= TEST_BLOCKS || block == 0)
                return -1;
        ++writes;
        if ((int)blockno == fail_block) {
                n = fail_words;
                if (n > BLOCKSET_BLOCK_WORDS)
                        n = BLOCKSET_BLOCK_WORDS;
                for (i = 0U; i < n; ++i)
                        media[(unsigned int)blockno][i] = block[i];
                fail_block = -1;
                fail_words = 0U;
                return -1;
        }
        for (i = 0U; i < BLOCKSET_BLOCK_WORDS; ++i)
                media[(unsigned int)blockno][i] = block[i];
        return 0;
}

static void
reset_test(void)
{
        unsigned int block;
        unsigned int word;

        for (block = 0U; block < TEST_BLOCKS; ++block)
                for (word = 0U; word < BLOCKSET_BLOCK_WORDS; ++word)
                        media[block][word] = 0UL;
        fail_block = -1;
        fail_words = 0U;
        writes = 0U;
        tape_status = MTC_ST_TAPE_FREE;
        tape_fail = 0;
        tape_writes = 0U;
        tape_sequence = 0UL;
        tape_unit = 0U;
}

static void
fault_once(unsigned int blockno, unsigned int words)
{
        fail_block = (int)blockno;
        fail_words = words;
}

static int
check_empty_recovery(void)
{
        struct logstore log;
        struct logstore_drain drain;
        kword_t scratch[BLOCKSET_BLOCK_WORDS];

        reset_test();
        if (logstore_recover(&log, scratch) != 0)
                return 1;
        if (log.capacity != 3U || log.next_sequence != 1UL ||
            log.next_slot != 0U)
                return 2;
        if (logstore_drain_recover(&log, &drain, scratch) != 0)
                return 3;
        if (drain.next_sequence != 1UL || drain.lost_records != 0UL ||
            drain.state_generation != 0UL ||
            drain.state_copy != LOGSTORE_STATE_NONE)
                return 4;
        return 0;
}

static int
check_record_recovery(void)
{
        struct logstore log;
        struct logstore recovered;
        struct logstore_drain drain;
        kword_t scratch[BLOCKSET_BLOCK_WORDS];
        kword_t payload[2];
        unsigned int before;

        reset_test();
        payload[0] = 012345670123UL;
        payload[1] = 076543210765UL;
        if (logstore_recover(&log, scratch) != 0)
                return 1;
        before = writes;
        if (logstore_append(&log, 6U, 1U, 01234UL, payload, 2U,
            scratch) != 0)
                return 2;
        if (writes != before + 1U || media[2][0] != LOGSTORE_RECORD_MAGIC ||
            media[2][1] != 1UL || media[2][2] != 01234UL ||
            media[2][4] != payload[0] || media[2][5] != payload[1] ||
            media[2][BLOCKSET_BLOCK_WORDS - 1U] == 0UL)
                return 3;
        if (logstore_recover(&recovered, scratch) != 0 ||
            recovered.next_sequence != 2UL || recovered.next_slot != 1U)
                return 4;

        fault_once(3U, BLOCKSET_BLOCK_WORDS - 1U);
        if (logstore_append(&recovered, 2U, 3U, 077UL, payload, 1U,
            scratch) == 0)
                return 5;
        if (logstore_recover(&log, scratch) != 0 ||
            log.next_sequence != 2UL || log.next_slot != 1U)
                return 6;
        if (logstore_append(&log, 2U, 3U, 077UL, payload, 1U,
            scratch) != 0 ||
            logstore_append(&log, 3U, 4U, 0100UL, payload, 0U,
            scratch) != 0)
                return 7;
        if (logstore_recover(&recovered, scratch) != 0 ||
            recovered.next_sequence != 4UL || recovered.next_slot != 0U)
                return 8;
        if (logstore_drain_recover(&recovered, &drain, scratch) != 0 ||
            drain.next_sequence != 1UL || drain.lost_records != 0UL)
                return 9;
        return 0;
}

static int
check_drain(void)
{
        struct logstore log;
        struct logstore recovered;
        struct logstore_drain drain;
        struct logstore_drain recovered_drain;
        kword_t scratch[BLOCKSET_BLOCK_WORDS];
        kword_t payload;
        unsigned int before;

        reset_test();
        payload = 055UL;
        if (logstore_recover(&log, scratch) != 0 ||
            logstore_append(&log, 1U, 1U, 0UL, &payload, 1U, scratch) != 0 ||
            logstore_append(&log, 2U, 1U, 0UL, &payload, 1U, scratch) != 0 ||
            logstore_append(&log, 3U, 1U, 0UL, &payload, 1U, scratch) != 0 ||
            logstore_recover(&recovered, scratch) != 0 ||
            logstore_drain_recover(&recovered, &drain, scratch) != 0 ||
            drain.next_sequence != 1UL)
                return 1;

        tape_status = 0;
        if (logstore_drain_one(&recovered, &drain, logstore_mtc_sink,
            &tape_unit, scratch) != LOGSTORE_DRAIN_REEL ||
            tape_writes != 0U || drain.next_sequence != 1UL)
                return 2;

        tape_status = MTC_ST_TAPE_FREE;
        tape_fail = 1;
        if (logstore_drain_one(&recovered, &drain, logstore_mtc_sink,
            &tape_unit, scratch) != -5 || tape_writes != 1U ||
            tape_sequence != 1UL || drain.next_sequence != 1UL)
                return 3;

        before = tape_writes;
        fault_once(0U, BLOCKSET_BLOCK_WORDS - 1U);
        if (logstore_drain_one(&recovered, &drain, logstore_mtc_sink,
            &tape_unit, scratch) == 0 || tape_writes != before + 1U ||
            tape_sequence != 1UL || drain.next_sequence != 1UL)
                return 4;
        if (logstore_drain_recover(&recovered, &recovered_drain,
            scratch) != 0 || recovered_drain.next_sequence != 1UL ||
            recovered_drain.state_generation != 0UL)
                return 5;

        if (logstore_drain_one(&recovered, &recovered_drain,
            logstore_mtc_sink, &tape_unit, scratch) != 0 ||
            tape_sequence != 1UL || recovered_drain.next_sequence != 2UL ||
            recovered_drain.state_generation != 1UL)
                return 6;

        tape_status = MTC_ST_TAPE_FREE | MTC_ST_EOT;
        if (logstore_drain_one(&recovered, &recovered_drain,
            logstore_mtc_sink, &tape_unit, scratch) != LOGSTORE_DRAIN_REEL ||
            recovered_drain.next_sequence != 2UL)
                return 7;
        tape_status = MTC_ST_TAPE_FREE;

        if (logstore_drain_one(&recovered, &recovered_drain,
            logstore_mtc_sink, &tape_unit, scratch) != 0 ||
            tape_sequence != 2UL ||
            logstore_drain_one(&recovered, &recovered_drain,
            logstore_mtc_sink, &tape_unit, scratch) != 0 ||
            tape_sequence != 3UL ||
            logstore_drain_one(&recovered, &recovered_drain,
            logstore_mtc_sink, &tape_unit, scratch) != LOGSTORE_DRAIN_EMPTY ||
            recovered_drain.next_sequence != 4UL)
                return 8;
        return 0;
}

static int
check_ring_loss(void)
{
        struct logstore log;
        struct logstore recovered;
        struct logstore_drain drain;
        struct logstore_drain recovered_drain;
        kword_t scratch[BLOCKSET_BLOCK_WORDS];
        kword_t payload;
        unsigned int before;

        reset_test();
        payload = 066UL;
        if (logstore_recover(&log, scratch) != 0 ||
            logstore_drain_recover(&log, &drain, scratch) != 0)
                return 1;
        if (logstore_append(&log, 1U, 1U, 0UL, &payload, 1U, scratch) != 0 ||
            logstore_append(&log, 1U, 1U, 0UL, &payload, 1U, scratch) != 0 ||
            logstore_append(&log, 1U, 1U, 0UL, &payload, 1U, scratch) != 0 ||
            logstore_append(&log, 1U, 1U, 0UL, &payload, 1U, scratch) != 0 ||
            logstore_recover(&recovered, scratch) != 0 ||
            recovered.next_sequence != 5UL || recovered.next_slot != 1U)
                return 2;

        tape_fail = 1;
        if (logstore_drain_one(&recovered, &drain, logstore_mtc_sink,
            &tape_unit, scratch) != -5 || drain.next_sequence != 2UL ||
            drain.lost_records != 1UL || drain.state_generation != 1UL ||
            drain.state_copy != 0U || tape_sequence != 2UL)
                return 3;
        if (logstore_drain_recover(&recovered, &recovered_drain,
            scratch) != 0 || recovered_drain.next_sequence != 2UL ||
            recovered_drain.lost_records != 1UL ||
            recovered_drain.state_generation != 1UL ||
            recovered_drain.state_copy != 0U)
                return 4;

        if (logstore_drain_one(&recovered, &recovered_drain,
            logstore_mtc_sink, &tape_unit, scratch) != 0 ||
            recovered_drain.next_sequence != 3UL ||
            recovered_drain.lost_records != 1UL ||
            recovered_drain.state_generation != 2UL ||
            recovered_drain.state_copy != 1U)
                return 5;

        before = tape_writes;
        fault_once(0U, BLOCKSET_BLOCK_WORDS - 1U);
        if (logstore_drain_one(&recovered, &recovered_drain,
            logstore_mtc_sink, &tape_unit, scratch) == 0 ||
            tape_writes != before + 1U || tape_sequence != 3UL ||
            recovered_drain.next_sequence != 3UL)
                return 6;
        if (logstore_drain_recover(&recovered, &drain, scratch) != 0 ||
            drain.next_sequence != 3UL || drain.lost_records != 1UL ||
            drain.state_generation != 2UL || drain.state_copy != 1U)
                return 7;

        if (logstore_drain_one(&recovered, &drain, logstore_mtc_sink,
            &tape_unit, scratch) != 0 || drain.next_sequence != 4UL ||
            logstore_drain_one(&recovered, &drain, logstore_mtc_sink,
            &tape_unit, scratch) != 0 || drain.next_sequence != 5UL ||
            logstore_drain_one(&recovered, &drain, logstore_mtc_sink,
            &tape_unit, scratch) != LOGSTORE_DRAIN_EMPTY)
                return 8;

        before = writes;
        recovered.next_sequence = LOGSTORE_WORD_MASK;
        if (logstore_append(&recovered, 1U, 1U, 0UL, &payload, 1U,
            scratch) == 0 || writes != before)
                return 9;
        return 0;
}

int
main(void)
{
        int rc;

        rc = check_empty_recovery();
        if (rc != 0)
                return 10 + rc;
        rc = check_record_recovery();
        if (rc != 0)
                return 30 + rc;
        rc = check_drain();
        if (rc != 0)
                return 50 + rc;
        rc = check_ring_loss();
        if (rc != 0)
                return 70 + rc;
        return 0;
}
