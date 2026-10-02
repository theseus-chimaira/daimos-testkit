#include "dsys.h"
#include "../test_sixbit.h"

static kword_t devices_path[] = {
        16UL,
        TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T'),
        TEST_SIX6('O', 'R', '/', 'D', 'E', 'V'),
        TEST_SIX6('I', 'C', 'E', 'S', ' ', ' ')
};

static int
name_is(const struct vfs_dirent *ent, unsigned int chars, kword_t word)
{
        return ent->name.chars == chars && ent->name.words[0] == word;
}

static unsigned int
present_bit(const struct vfs_dirent *ent)
{
        if (name_is(ent, 4U, TEST_SIX6('C','T','Y','0',' ',' '))) return 0001U;
        if (name_is(ent, 4U, TEST_SIX6('C','L','K','0',' ',' '))) return 0002U;
        if (name_is(ent, 4U, TEST_SIX6('P','T','R','0',' ',' '))) return 0004U;
        if (name_is(ent, 4U, TEST_SIX6('T','T','Y','0',' ',' '))) return 0010U;
        if (name_is(ent, 6U, TEST_SIX6('O','C','N','S','L','S'))) return 0020U;
        if (name_is(ent, 4U, TEST_SIX6('D','S','K','0',' ',' '))) return 0040U;
        if (name_is(ent, 6U, TEST_SIX6('D','6','S','E','T','0'))) return 0100U;
        if (name_is(ent, 4U, TEST_SIX6('D','R','M','0',' ',' '))) return 0200U;
        return 0U;
}

static int
must_be_absent(const struct vfs_dirent *ent)
{
        return name_is(ent, 4U, TEST_SIX6('P','T','P','0',' ',' ')) ||
            name_is(ent, 3U, TEST_SIX6('C','R','0',' ',' ',' ')) ||
            name_is(ent, 3U, TEST_SIX6('C','P','0',' ',' ',' ')) ||
            name_is(ent, 4U, TEST_SIX6('D','C','S','0',' ',' ')) ||
            name_is(ent, 3U, TEST_SIX6('G','E','0',' ',' ',' ')) ||
            name_is(ent, 4U, TEST_SIX6('D','T','C','0',' ',' ')) ||
            name_is(ent, 4U, TEST_SIX6('M','T','C','0',' ',' ')) ||
            name_is(ent, 4U, TEST_SIX6('S','L','V','0',' ',' '));
}

static void
fail(int ch)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
        (void)dsys_exit(1);
}

int
main(void)
{
        struct vfs_dirent ent;
        unsigned int seen;
        int fd;
        int rc;

        if (dsys_writechar(1, '<') != 0)
                fail('0');
        fd = dsys_open(devices_path, SYS_O_RDONLY);
        if (fd < 3)
                fail('1');
        seen = 0U;
        for (;;) {
                rc = dsys_dirread(fd, &ent);
                if (rc < 0)
                        fail('2');
                if (rc == 0)
                        break;
                if (must_be_absent(&ent))
                        fail('3');
                seen |= present_bit(&ent);
        }
        if (dsys_close(fd) != 0)
                fail('4');
        if (seen != 0377U)
                fail('5');
        (void)dsys_writechar(1, 'H');
        (void)dsys_exit(0);
        return 0;
}
