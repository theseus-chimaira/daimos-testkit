/* Test harness prepended/appended around the exact userland function bodies.
 * C89 and ASCII only.  Only fsinfo, output and provider I/O are mocked. */
#include <stdio.h>
#include <string.h>

typedef unsigned long kword_t;
struct u_io { int in_fd; int out_fd; int err_fd; };
struct sys_fsinfo {
    kword_t mount_id;
    kword_t provider;
    kword_t flags;
    kword_t total_words;
    kword_t used_words;
    kword_t path[18];
};
#define SYS_FSINFO_CAPACITY_SLOT (~0U)
#define SYS_MOUNT_RDONLY 1U

static int cap_v1492;
static int injected_failure_v1492;
static int capacity_queries_v1492;
static int slots_seen_v1492[26];
static int output_errors_v1492;
static int output_entries_v1492;

static int
dsys_fsinfo(unsigned int slot, struct sys_fsinfo *info)
{
    if (slot == SYS_FSINFO_CAPACITY_SLOT) {
        ++capacity_queries_v1492;
        return cap_v1492;
    }
    if (slot >= (unsigned int)cap_v1492 || slot >= 26U)
        return -1;
    ++slots_seen_v1492[slot];
    if ((int)slot == injected_failure_v1492)
        return -1;
    if (slot != 0U && slot != (unsigned int)cap_v1492 - 1U)
        return 0;
    if (!info)
        return -1;
    info->mount_id = (kword_t)slot + 1UL;
    info->provider = 6UL;
    info->flags = 0UL;
    info->total_words = 100UL;
    info->used_words = 20UL;
    info->path[0] = info->mount_id;
    return 1;
}

static int cmd_err(struct u_io *io, const char *name, kword_t *path)
{
    (void)io;
    (void)name;
    (void)path;
    ++output_errors_v1492;
    return 1;
}
static int cmd_put_fsname(int fd, kword_t provider)
{
    (void)fd;
    if (provider != 6UL)
        return 1;
    ++output_entries_v1492;
    return 0;
}
static int u_puts(int fd, const char *s)
{
    (void)fd;
    (void)s;
    return 0;
}
static int u_putc(int fd, int c)
{
    (void)fd;
    (void)c;
    return 0;
}
static int u_put_s6(int fd, const kword_t *s)
{
    (void)fd;
    return *s == 0UL ? 1 : 0;
}
static int u_put_uint(int fd, kword_t n)
{
    (void)fd;
    (void)n;
    return 0;
}
static int u_crlf(int fd)
{
    (void)fd;
    return 0;
}

/* v1492 test entry follows source-injected command bodies. */
static void
reset_v1492(int capacity, int fail_slot)
{
    unsigned int i;
    cap_v1492 = capacity;
    injected_failure_v1492 = fail_slot;
    capacity_queries_v1492 = 0;
    output_errors_v1492 = 0;
    output_entries_v1492 = 0;
    for (i = 0U; i < 26U; ++i)
        slots_seen_v1492[i] = 0;
}

static int
verify_v1492(int capacity, int is_df, int fail_slot)
{
    struct u_io io;
    int rc;
    int expected;
    int i;

    io.in_fd = 0;
    io.out_fd = 1;
    io.err_fd = 2;
    reset_v1492(capacity, fail_slot);
    if (is_df)
        rc = cmd_df(1, 0, &io);
    else
        rc = cmd_mounts(1, 0, &io);
    expected = (capacity <= 0 || fail_slot >= 0) ? 1 : 0;
    if (rc != expected || capacity_queries_v1492 != 1 ||
        output_errors_v1492 != expected)
        return -1;
    if (capacity <= 0)
        return 0;
    for (i = 0; i < capacity; ++i) {
        expected = (fail_slot < 0 || i <= fail_slot) ? 1 : 0;
        if (slots_seen_v1492[i] != expected)
            return -2;
    }
    expected = capacity == 1 ? 1 : 2;
    if (fail_slot >= 0)
        expected = fail_slot == 0 ? 0 : 1;
    if (output_entries_v1492 != expected)
        return -3;
    return 0;
}

int
main(void)
{
    static const int sizes[] = { 1, 4, 8, 17, 26 };
    unsigned int i;
    int mode;

    for (mode = 0; mode < 2; ++mode) {
        for (i = 0; i < sizeof(sizes) / sizeof(sizes[0]); ++i)
            if (verify_v1492(sizes[i], mode, -1) != 0)
                return 1;
        if (verify_v1492(8, mode, 4) != 0)
            return 2;
        if (verify_v1492(0, mode, -1) != 0)
            return 3;
        if (verify_v1492(-1, mode, -1) != 0)
            return 4;
    }
    return 0;
}
