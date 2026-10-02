#include "file.h"
#include "../../test_sixbit.h"

extern int file_component(const kword_t *, unsigned int *,
    struct vfs_name *);
extern int file_new_fd(vnode_t, unsigned int, int);
extern struct file *file_table;

kword_t daimos_file_pdp6_result;

static int
name_eq(const struct vfs_name *name, unsigned int chars,
    kword_t w0, kword_t w1, kword_t w2, kword_t w3)
{
        return name->chars == chars && name->words[0] == w0 &&
            name->words[1] == w1 && name->words[2] == w2 &&
            name->words[3] == w3;
}

int
daimos_file_pdp6_test(void)
{
        static const kword_t p1[] = {
                8U,
                TEST_SIX6('/','F','O','O','/','B'),
                TEST_SIX6('A','R',' ',' ',' ',' ')
        };
        static const kword_t p2[] = {
                8U,
                TEST_SIX6('/','/','/','A','/','/'),
                TEST_SIX6('B','/',' ',' ',' ',' ')
        };
        static const kword_t p24[] = {
                24U,
                TEST_SIX6('A','B','C','D','E','F'),
                TEST_SIX6('G','H','I','J','K','L'),
                TEST_SIX6('M','N','O','P','Q','R'),
                TEST_SIX6('S','T','U','V','W','X')
        };
        static const kword_t p25[] = {
                25U,
                TEST_SIX6('A','B','C','D','E','F'),
                TEST_SIX6('G','H','I','J','K','L'),
                TEST_SIX6('M','N','O','P','Q','R'),
                TEST_SIX6('S','T','U','V','W','X'),
                TEST_SIX6('Y',' ',' ',' ',' ',' ')
        };
        struct vfs_name name;
        struct file table[FILE_NFILE];
        unsigned int pos;
        unsigned int i;
        vnode_t vnode;
        kword_t fulloff;
        int fd0;
        int fd1;
        int fd2;
        int rc;

        if (FILE_FD_FIRST != 0U || FILE_FD_MAX != 15U || FILE_NFILE != 16U)
                return 21;

        pos = 0U;
        rc = file_component(p1, &pos, &name);
        if (rc != 1 || pos != 5U ||
            !name_eq(&name, 3U,
            TEST_SIX6('F','O','O',' ',' ',' '), 0, 0, 0))
                return 1;
        rc = file_component(p1, &pos, &name);
        if (rc != 1 || pos != 8U ||
            !name_eq(&name, 3U,
            TEST_SIX6('B','A','R',' ',' ',' '), 0, 0, 0))
                return 2;
        if (file_component(p1, &pos, &name) != 0 || pos != 8U)
                return 3;

        pos = 0U;
        rc = file_component(p2, &pos, &name);
        if (rc != 1 || pos != 6U ||
            !name_eq(&name, 1U,
            TEST_SIX6('A',' ',' ',' ',' ',' '), 0, 0, 0))
                return 4;
        rc = file_component(p2, &pos, &name);
        if (rc != 1 || pos != 8U ||
            !name_eq(&name, 1U,
            TEST_SIX6('B',' ',' ',' ',' ',' '), 0, 0, 0))
                return 5;
        if (file_component(p2, &pos, &name) != 0 || pos != 8U)
                return 6;

        pos = 0U;
        rc = file_component(p24, &pos, &name);
        if (rc != 1 || pos != 24U || name.chars != 24U ||
            name.words[0] != p24[1] || name.words[1] != p24[2] ||
            name.words[2] != p24[3] || name.words[3] != p24[4])
                return 7;
        pos = 0U;
        if (file_component(p25, &pos, &name) != -1)
                return 8;
        pos = 0U;
        if (file_component(0, &pos, &name) != -1)
                return 9;
        if (file_component(p1, 0, &name) != -1)
                return 10;
        if (file_component(p1, &pos, 0) != -1)
                return 11;

        for (i = 0U; i != FILE_NFILE; ++i) {
                table[i].node_meta = 0UL;
                table[i].offset = 0UL;
        }
        file_table = table;
        vnode = VFS_NODE(4U, VFS_MOUNT_KIND(2U, 1U), 0123456U);
        if (file_new_fd(vnode | FILE_META_READ, FILE_O_READ, 0) != -1)
                return 20;
        fd0 = file_new_fd(vnode, FILE_O_READ | FILE_O_WRITE | FILE_O_APPEND,
            0);
        if (fd0 != FILE_FD_FIRST || FILE_NODE(table[0].node_meta) != vnode ||
            (table[0].node_meta & FILE_META_READ) == 0UL ||
            (table[0].node_meta & FILE_META_WRITE) == 0UL ||
            (table[0].node_meta & FILE_META_DIR) != 0UL ||
            (table[0].node_meta & FILE_META_OWNER_MASK) != 0UL ||
            (table[0].node_meta & FILE_META_STATE_MASK) != 0UL)
                return 12;

        table[0].node_meta |= FILE_META_REGULAR;
        fulloff = 0777777777777UL;
        table[0].offset = fulloff;
        fd1 = file_dup(fd0);
        if (fd1 != FILE_FD_FIRST + 1 ||
            table[1].node_meta != table[0].node_meta ||
            table[1].offset != fulloff)
                return 13;
        if (file_lock(fd0, VFS_LOCK_SHARED) != 0 ||
            (table[0].node_meta & FILE_META_STATE_MASK) !=
                FILE_META_LOCK_SHARED ||
            (table[1].node_meta & FILE_META_STATE_MASK) !=
                FILE_META_LOCK_SHARED)
                return 14;

        fd2 = file_new_fd(vnode, FILE_O_READ, 0);
        if (fd2 != FILE_FD_FIRST + 2)
                return 15;
        table[2].node_meta |= FILE_META_REGULAR;
        if (file_lock(fd2, VFS_LOCK_EXCLUSIVE) != -1)
                return 16;
        if (file_lock(fd0, VFS_LOCK_UNLOCK) != 0 ||
            (table[0].node_meta & FILE_META_STATE_MASK) != FILE_META_REGULAR ||
            (table[1].node_meta & FILE_META_STATE_MASK) != FILE_META_REGULAR)
                return 17;
        if (file_lock(fd2, VFS_LOCK_EXCLUSIVE) != 0 ||
            file_lock(fd0, VFS_LOCK_SHARED) != -1)
                return 18;
        if (file_close(fd2) != 0 || table[2].node_meta != 0UL)
                return 19;
        return 0;
}
