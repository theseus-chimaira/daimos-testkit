#include "proc_swap.h"
#include "vm_pdp6.h"
#include "exec.h"
#include "bstore.h"
#include "bcache.h"
#include "fs_mres.h"
#include "memfs.h"

#define TEST_WORDS       04000U
#define TEST_TEXT_WORDS  01000U
#define TEST_BLOCKS      (TEST_WORDS / DSK_WORDS_PER_SECTOR)
#define TEST_NODE VFS_NODE(MEMFS_PROVIDER, \
    VFS_MOUNT_KIND(1U, MEMFS_KIND_NODE), 012345U)

static struct proc processes[2];
static struct proc_swap_record records[2];
static kword_t uarea[PROC_UAREA_WORDS];
static kword_t resident[TEST_WORDS];
static kword_t restored[TEST_WORDS];
static kword_t swap_image[TEST_WORDS];
static kword_t exec_text[02000];
static kword_t allocated_base;
static kword_t allocated_blocks;
static int exec_compressed;

struct proc *proc_table = processes;
unsigned int proc_slots = 2U;
unsigned int proc_high_slot = 2U;
kword_t proc_sched_cursor;
kword_t backstore_blocks = TEST_BLOCKS;
kword_t backstore_blocks_used;
unsigned int backstore_enabled = 1U;
kword_t *backstore_bitmap;
kword_t fs_block_workspace[DSK_WORDS_PER_SECTOR];
kword_t daimos_swap_pure_text_pdp6_result;

static void
copy_words(kword_t *dst, const kword_t *src, unsigned int words)
{
        unsigned int i;

        for (i = 0U; i < words; ++i)
                dst[i] = src[i];
}

void
bcache_workspace_invalidate(void)
{
}

void
fs_zero_words(kword_t *dst, unsigned int words)
{
        unsigned int i;

        for (i = 0U; i < words; ++i)
                dst[i] = 0UL;
}

int
mm_is_pinned(kword_t base)
{
        (void)base;
        return 0;
}

int
mm_pin(kword_t base)
{
        (void)base;
        return 0;
}

int
mm_unpin(kword_t base)
{
        (void)base;
        return 0;
}

int
mm_free(kword_t base, unsigned int type, unsigned int owner)
{
        (void)base;
        (void)type;
        (void)owner;
        return 0;
}

int
mm_alloc_aligned(kword_t words, kword_t alignment, unsigned int type,
    unsigned int owner, unsigned int flags, kword_t *basep)
{
        (void)alignment;
        (void)type;
        (void)owner;
        (void)flags;
        if (words != TEST_WORDS || basep == 0)
                return -1;
        *basep = (kword_t)(unsigned long)restored;
        return 0;
}

int
backstore_alloc(kword_t blocks, kword_t reserve, kword_t *firstp)
{
        (void)reserve;
        if (blocks == 0UL || blocks > TEST_BLOCKS || firstp == 0)
                return -1;
        allocated_blocks = blocks;
        allocated_base = 0UL;
        backstore_blocks_used = blocks;
        *firstp = allocated_base;
        return 0;
}

void
backstore_free(kword_t first, kword_t blocks)
{
        if (first == allocated_base && blocks == allocated_blocks) {
                allocated_blocks = 0UL;
                backstore_blocks_used = 0UL;
        }
}

int
backstore_write(kword_t first, kword_t blocks, const kword_t *buf)
{
        kword_t offset;

        if (first < allocated_base ||
            first + blocks > allocated_base + allocated_blocks)
                return -1;
        offset = (first - allocated_base) * DSK_WORDS_PER_SECTOR;
        copy_words(swap_image + offset, buf,
            (unsigned int)(blocks * DSK_WORDS_PER_SECTOR));
        return 0;
}

int
backstore_read(kword_t first, kword_t blocks, kword_t *buf)
{
        kword_t offset;

        if (first < allocated_base ||
            first + blocks > allocated_base + allocated_blocks)
                return -1;
        offset = (first - allocated_base) * DSK_WORDS_PER_SECTOR;
        copy_words(buf, swap_image + offset,
            (unsigned int)(blocks * DSK_WORDS_PER_SECTOR));
        return 0;
}

int
vfs_stat(vnode_t node, struct vfs_stat *st)
{
        kword_t reloc;
        kword_t payload;

        if (node != TEST_NODE || st == 0)
                return -1;
        reloc = (02000UL + 35UL) / 36UL;
        payload = exec_compressed ?
            02000UL + (02000UL + 35UL) / 36UL : 02000UL;
        st->type = VFS_TYPE_REG;
        st->size_words = EXEC_DXR_EXT_HDR_WORDS + payload + reloc;
        return 0;
}

int
vfs_read_words(vnode_t node, unsigned int off, kword_t *buf,
    unsigned int words)
{
        kword_t header[EXEC_DXR_EXT_HDR_WORDS];
        unsigned int i;
        unsigned int stream_index;
        unsigned int group;
        unsigned int pos;
        unsigned int token;

        if (node != TEST_NODE || buf == 0)
                return -1;
        header[0] = 0447062UL << 18U;
        header[1] = (02000UL << 18U) | EXEC_DXR_F_PURE |
            (exec_compressed ? EXEC_DXR_F_COMPRESSED : 0UL);
        header[2] = ((kword_t)TEST_TEXT_WORDS << 18U) | EXEC_DXR_TEXT_TAG;
        if (off < EXEC_DXR_EXT_HDR_WORDS &&
            words <= EXEC_DXR_EXT_HDR_WORDS - off) {
                for (i = 0U; i < words; ++i)
                        buf[i] = header[off + i];
                return (int)words;
        }
        if (exec_compressed) {
                unsigned int payload_words =
                    02000U + (02000U + 35U) / 36U;
                unsigned int available;

                if (off < EXEC_DXR_EXT_HDR_WORDS ||
                    off - EXEC_DXR_EXT_HDR_WORDS >= payload_words)
                        return 0;
                available = payload_words -
                    (off - EXEC_DXR_EXT_HDR_WORDS);
                if (words > available)
                        words = available;
                for (i = 0U; i < words; ++i) {
                        stream_index = off - EXEC_DXR_EXT_HDR_WORDS + i;
                        group = stream_index / 37U;
                        pos = stream_index % 37U;
                        if (pos == 0U) {
                                buf[i] = 0UL;
                        } else {
                                token = group * 36U + pos - 1U;
                                if (token >= 02000U)
                                        return -1;
                                buf[i] = exec_text[token];
                        }
                }
                return (int)words;
        }
        if (off < EXEC_DXR_EXT_HDR_WORDS ||
            off - EXEC_DXR_EXT_HDR_WORDS > 02000U ||
            words > 02000U - (off - EXEC_DXR_EXT_HDR_WORDS))
                return -1;
        for (i = 0U; i < words; ++i)
                buf[i] = exec_text[off - EXEC_DXR_EXT_HDR_WORDS + i];
        return (int)words;
}

static void
setup_process(int compressed)
{
        unsigned int i;

        for (i = 0U; i < PROC_UAREA_WORDS; ++i)
                uarea[i] = 0UL;
        for (i = 0U; i < TEST_WORDS; ++i) {
                resident[i] = 0500000000000UL + (kword_t)i;
                restored[i] = 0UL;
                swap_image[i] = 0UL;
        }
        for (i = 0U; i < 02000U; ++i)
                exec_text[i] = 0400000000000UL + (kword_t)i;
        for (i = 0U; i < TEST_TEXT_WORDS; ++i)
                resident[EXEC_USER_ORIGIN + i] = exec_text[i];
        processes[1].meta =
            ((kword_t)(unsigned long)uarea << PROC_HALF_SHIFT) |
            ((kword_t)PROC_F_UAREA << PROC_FLAGS_SHIFT);
        VM_PDP6_SET_SPACE(&processes[1], TEST_WORDS,
            (kword_t)(unsigned long)resident);
        processes[1].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&processes[1], PROC_STOP);
        records[1].state = 0UL;
        proc_swap_records = records;
        proc_swap_blocks_used = 0UL;
        allocated_blocks = 0UL;
        backstore_blocks_used = 0UL;
        exec_compressed = compressed;
}

int
daimos_swap_pure_text_pdp6_test(void)
{
#ifdef TEST_VERIFY_PURE
        setup_process(0);
        resident[0400U] ^= 1UL;
        if (proc_swap_attach(1, TEST_NODE, TEST_TEXT_WORDS, 1U) != 0)
                return 1;
        daimos_swap_pure_text_pdp6_result = 1UL;
        if (proc_swap_out(1) != 0)
                return 2;
        daimos_swap_pure_text_pdp6_result = 3UL;
        return 3;
#else
        kword_t clean_blocks;

        setup_process(0);
        if (proc_swap_attach(1, TEST_NODE, TEST_TEXT_WORDS, 1U) != 0)
                return 1;
        if (proc_swap_out(1) != 0)
                return 2;
        clean_blocks = (TEST_WORDS - 01000UL) / DSK_WORDS_PER_SECTOR;
        if (VM_PDP6_BASE(&processes[1]) != 0UL)
                return 031;
        if (proc_swap_backing_busy(TEST_NODE) == 0)
                return 035;
        if (proc_swap_mount_busy(1U) == 0)
                return 041;
        if (allocated_blocks != clean_blocks)
                return 032;
        if (proc_swap_blocks_used != clean_blocks)
                return 033;
        if (PROC_SWAP_BACKING_WORD(&processes[1]) == 0UL)
                return 034;
        if (proc_swap_in(1) != 0)
                return 4;
        if (proc_swap_backing_busy(TEST_NODE) != 0)
                return 036;
        if (proc_swap_mount_busy(1U) != 0)
                return 042;
        if (VM_PDP6_BASE(&processes[1]) !=
            (kword_t)(unsigned long)restored)
                return 5;
        if (restored[020U] != exec_text[0] ||
            restored[01017U] != exec_text[0777U] ||
            restored[01020U] != 0500000000000UL + 01020UL ||
            allocated_blocks != 0UL || proc_swap_blocks_used != 0UL)
                return 6;

        /* A non-PURE image never acquires executable-backed text semantics
         * and therefore uses the historical whole-image swap transaction. */
        setup_process(0);
        resident[0400U] ^= 1UL;
        if (proc_swap_attach(1, TEST_NODE, TEST_TEXT_WORDS, 0U) != 0)
                return 7;
        if (proc_swap_out(1) != 0 || allocated_blocks != TEST_BLOCKS)
                return 8;
        if (proc_swap_backing_busy(TEST_NODE) != 0 ||
            proc_swap_mount_busy(1U) != 0)
                return 9;
        if (proc_swap_in(1) != 0 ||
            restored[0400U] != resident[0400U])
                return 10;

        setup_process(1);
        if (proc_swap_attach(1, TEST_NODE, TEST_TEXT_WORDS, 1U) != 0)
                return 12;
        if (proc_swap_out(1) != 0 || allocated_blocks != clean_blocks)
                return 13;
        if (proc_swap_in(1) != 0)
                return 14;
        if (restored[020U] != exec_text[0] ||
            restored[01017U] != exec_text[0777U] ||
            restored[01020U] != 0500000000000UL + 01020UL)
                return 15;

        return 0;
#endif
}
