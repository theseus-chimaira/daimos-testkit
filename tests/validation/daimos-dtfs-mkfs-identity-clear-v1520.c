/* Execute production MKFS.DTFS C through its actual command entry.
 * The test supplies only syscall and counted-name dependencies. */
#include "cmd.h"
#include "dtfs_media.h"
#include <stdio.h>
#include <string.h>

static kword_t opt_o[2];
static kword_t opt_native[2];
static kword_t device[2];
static unsigned int writes;
static unsigned int bad_write;
static int fail_identity_write;

int
u_s6_eq(const kword_t *record, const char *name)
{
        if (record == opt_o && strcmp(name, "-O") == 0)
                return 1;
        if (record == device && strcmp(name, "/DEV/DTC3") == 0)
                return 1;
        return 0;
}

int
u_puts(int fd, const char *string)
{
        (void)fd;
        (void)string;
        return 0;
}

int
u_put_s6(int fd, const kword_t *name)
{
        (void)fd;
        (void)name;
        return 0;
}

int
u_crlf(int fd)
{
        (void)fd;
        return 0;
}

int
dsys_dtc_write_block(unsigned int unit, unsigned int block, kword_t *data)
{
        unsigned int i;

        if (unit != 3U)
                ++bad_write;
        if (writes == 0U) {
                if (block != DTFS_ID_BLOCK_V1520)
                        ++bad_write;
                for (i = 0U; i < DTFS_BLOCK_WORDS; ++i)
                        if (data[i] != 0UL)
                                ++bad_write;
        } else if (writes == 1U) {
                if (block != DTFS_DIR_BLOCK ||
                    data[DTFS_MAGIC_WORD] != DTFS_NATIVE_MAGIC ||
                    data[0] != ((kword_t)DTFS_OWNER_RESERVED << 31U))
                        ++bad_write;
        } else {
                ++bad_write;
        }
        ++writes;
        if (block == DTFS_ID_BLOCK_V1520 && fail_identity_write)
                return -1;
        return 0;
}

static void
pack_sixbit(kword_t *record, const char *value)
{
        unsigned int i;
        unsigned int len;

        len = (unsigned int)strlen(value);
        record[0] = (kword_t)len;
        record[1] = 0UL;
        for (i = 0U; i < len; ++i)
                record[1] |= (kword_t)((unsigned int)value[i] - 040U) <<
                    (30U - i * 6U);
}

int
main(void)
{
        struct u_io io;
        kword_t *args[4];
        int result;

        memset(&io, 0, sizeof(io));
        pack_sixbit(opt_native, "NATIVE");
        args[0] = opt_o;
        args[1] = opt_o;
        args[2] = opt_native;
        args[3] = device;

        writes = 0U;
        bad_write = 0U;
        fail_identity_write = 1;
        result = cmd_program_MKFS_DTFS(4, args, &io);
        if (result != 1 || writes != 1U || bad_write != 0U) {
                fprintf(stderr, "FAIL v1520: old identity not cleared"
                    " fail-close result=%d writes=%u bad=%u\n",
                    result, writes, bad_write);
                return 1;
        }
        puts("PASS v1520: target MKFS aborts before directory if identity clear fails");

        writes = 0U;
        bad_write = 0U;
        fail_identity_write = 0;
        result = cmd_program_MKFS_DTFS(4, args, &io);
        if (result != 0 || writes != 2U || bad_write != 0U) {
                fprintf(stderr, "FAIL v1520: target MKFS identity reset"
                    " result=%d writes=%u bad=%u\n",
                    result, writes, bad_write);
                return 1;
        }
        puts("PASS v1520: target MKFS clears old identity before directory publication");
        return 0;
}
