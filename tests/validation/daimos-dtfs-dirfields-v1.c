#include "kcore.h"

int __test_exit;
kword_t *dtfs_dir;
static kword_t dirbuf[0200];

extern void dtfs_clear_slot(unsigned int slot);
extern void dtfs_set_last_words(unsigned int slot, unsigned int words);
extern void dtfs_set_exec(unsigned int slot, int executable);

int
main(void)
{
        unsigned int slot;
        unsigned int wi;
        kword_t keep;

        dtfs_dir = dirbuf;

        slot = 3U;
        wi = 0123U + slot * 2U;
        dirbuf[wi] = 012345670123UL;
        dirbuf[wi + 1U] = 076543210765UL;
        dirbuf[slot] = 012345670121UL;
        dirbuf[026U + slot] = 076543210765UL;
        keep = dirbuf[slot] & ~1UL;
        dtfs_clear_slot(slot);
        if (dirbuf[wi] != 0UL || dirbuf[wi + 1U] != 0UL ||
            dirbuf[slot] != keep || (dirbuf[026U + slot] & 1UL) != 0UL)
                return 1;

        slot = 4U;
        wi = 0124U + slot * 2U;
        dirbuf[wi] = 012345670100UL;
        dirbuf[026U + slot] = 076543210764UL;
        dtfs_set_last_words(slot, 0177U);
        if ((dirbuf[wi] & 077UL) != 077UL ||
            (dirbuf[026U + slot] & 1UL) != 1UL)
                return 2;
        dtfs_set_last_words(slot, 5U);
        if ((dirbuf[wi] & 077UL) != 5UL ||
            (dirbuf[026U + slot] & 1UL) != 0UL)
                return 3;

        slot = 5U;
        dirbuf[slot] = 012345670120UL;
        keep = dirbuf[slot] & ~1UL;
        dtfs_set_exec(slot, 1);
        if (dirbuf[slot] != (keep | 1UL))
                return 4;
        dtfs_set_exec(slot, 0);
        if (dirbuf[slot] != keep)
                return 5;
        return 0;
}
