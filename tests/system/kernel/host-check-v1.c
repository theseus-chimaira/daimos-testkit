/* Host-side binary and display checks for the DAIMOS PDP-6 runtime suite. */
#include <ctype.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define WORD36_MASK UINT64_C(0777777777777)
#define HALF18_MASK UINT64_C(0777777)
#define DPY_MODE_POINT 1U
#define DPY_MODE_CHAR 3U
#define TYPE342_SPACE 040U
#define WCNSLS_GREEN_CONO 03740U

static const uint64_t wcnsls_title[] = {
    UINT64_C(0364306143076), UINT64_C(0164307743061),
    UINT64_C(0371020410237), UINT64_C(0216726543061),
    UINT64_C(0164306143056), UINT64_C(0174101602076), 0
};
static const uint64_t wcnsls_digits[] = {
    UINT64_C(0164316563056), UINT64_C(0043020410216),
    UINT64_C(0164204210437), UINT64_C(0360205602076),
    UINT64_C(0021452276102), UINT64_C(0374103602076),
    UINT64_C(0164103643056), UINT64_C(0370210420410),
    UINT64_C(0164305643056), UINT64_C(0164305702056)
};
#define WCNSLS_GLYPH_V UINT64_C(0214306142504)
#define WCNSLS_GLYPH_DOT UINT64_C(0000000000306)
#define WCNSLS_GLYPH_DASH UINT64_C(0000003700000)

static void
fail(const char *msg)
{
    fprintf(stderr, "host-check-v1: %s\n", msg);
    exit(1);
}

static uint32_t
le32(const unsigned char b[4])
{
    return (uint32_t)b[0] | ((uint32_t)b[1] << 8) |
           ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

static uint64_t
parse_octal(const char *s)
{
    char *end;
    unsigned long long value;

    errno = 0;
    value = strtoull(s, &end, 8);
    if (errno != 0 || end == s || *end != '\0' || value > WORD36_MASK)
        fail("invalid octal word");
    return (uint64_t)value;
}

static void
read_version(const char *path, char *buf, size_t size)
{
    FILE *fp;
    size_t n;

    fp = fopen(path, "r");
    if (fp == NULL)
        fail("cannot open VERSION");
    if (fgets(buf, (int)size, fp) == NULL) {
        fclose(fp);
        fail("cannot read VERSION");
    }
    fclose(fp);
    n = strlen(buf);
    while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r'))
        buf[--n] = '\0';
}

static int
check_ptp(int argc, char **argv)
{
    FILE *fp;
    int ch;

    if (argc != 1)
        fail("ptp requires FILE");
    fp = fopen(argv[0], "rb");
    if (fp == NULL)
        fail("cannot open PTP output");
    ch = fgetc(fp);
    if (ch != 0252 || fgetc(fp) != EOF) {
        fclose(fp);
        fail("PTP output mismatch");
    }
    fclose(fp);
    puts("PDP-6 PTP output test PASS");
    return 0;
}

static int
check_dtc(int argc, char **argv)
{
    FILE *fp;
    long block;
    char *end;
    uint64_t base;
    int i;

    if (argc != 3)
        fail("dtc requires TAPE BLOCK BASE");
    base = parse_octal(argv[2]);
    block = strtol(argv[1], &end, 10);
    if (*argv[1] == '\0' || *end != '\0' || block < 0)
        fail("invalid DTC block");
    fp = fopen(argv[0], "rb");
    if (fp == NULL)
        fail("cannot open DECtape image");
    if (fseek(fp, block * 256L * 4L, SEEK_SET) != 0) {
        fclose(fp);
        fail("DTC block outside image");
    }
    for (i = 0; i < 128; ++i) {
        unsigned char raw[8];
        uint32_t hi, lo;
        uint64_t got;
        if (fread(raw, 1, sizeof raw, fp) != sizeof raw) {
            fclose(fp);
            fail("short DECtape block");
        }
        hi = le32(raw) & 0x3ffffU;
        lo = le32(raw + 4) & 0x3ffffU;
        got = ((uint64_t)hi << 18) | lo;
        if (got != ((base + (uint64_t)i) & WORD36_MASK)) {
            fprintf(stderr, "host-check-v1: DTC block word %d: got %012llo expected %012llo\n",
                    i, (unsigned long long)got,
                    (unsigned long long)((base + (uint64_t)i) & WORD36_MASK));
            fclose(fp);
            return 1;
        }
    }
    fclose(fp);
    puts("PDP-6 DTC resident block write test PASS");
    return 0;
}

static int
read_dtc_block(FILE *fp, unsigned int block, uint64_t words[128])
{
    unsigned int i;

    if (fseek(fp, (long)block * 256L * 4L, SEEK_SET) != 0)
        return -1;
    for (i = 0; i < 128U; ++i) {
        unsigned char raw[8];
        uint32_t hi, lo;

        if (fread(raw, 1, sizeof raw, fp) != sizeof raw)
            return -1;
        hi = le32(raw) & 0x3ffffU;
        lo = le32(raw + 4) & 0x3ffffU;
        words[i] = ((uint64_t)hi << 18) | lo;
    }
    return 0;
}

#define DTFS_BLOCKS 578U
#define DTFS_LAST_BLOCK 577U
#define DTFS_DIR_BLOCK 100U
#define DTFS_MAP_WORDS 83U
#define DTFS_FILE_SLOTS 22U
#define DTFS_NAME_BASE 83U
#define DTFS_MAGIC_WORD 127U
#define DTFS_DATA_WORDS 127U
#define DTFS_OWNER_FREE 0U
#define DTFS_OWNER_NATIVE_TAG 035U
#define DTFS_OWNER_RESERVED 036U
#define DTFS_NATIVE_MAGIC UINT64_C(0446446632021)

static unsigned int
dtfs_owner(const uint64_t dir[128], unsigned int block)
{
    unsigned int wi = block / 7U;
    unsigned int shift = 31U - (block % 7U) * 5U;
    return (unsigned int)((dir[wi] >> shift) & 037U);
}

static unsigned int
dtfs_last_words(const uint64_t dir[128], unsigned int slot)
{
    unsigned int low;
    unsigned int high;

    low = (unsigned int)(dir[DTFS_NAME_BASE + slot * 2U + 1U] & 077U);
    high = (dir[22U + slot] & 1U) != 0 ? 0100U : 0U;
    return low | high;
}

static unsigned int
dtfs_hdr_next(uint64_t h)
{
    return (unsigned int)((h >> 18U) & 01777U);
}

static unsigned int
dtfs_hdr_first(uint64_t h)
{
    return (unsigned int)((h >> 8U) & 01777U);
}

static unsigned int
dtfs_hdr_count(uint64_t h)
{
    return (unsigned int)(h & 0377U);
}

static int
check_dtfs(int argc, char **argv)
{
    FILE *fp;
    uint64_t dir[128];
    uint64_t block_words[128];
    unsigned char chained[DTFS_BLOCKS];
    unsigned int slot, block, owner;

    if (argc != 1)
        fail("dtfs requires TAPE");
    fp = fopen(argv[0], "rb");
    if (fp == NULL)
        fail("cannot open DTFS DECtape image");
    if (read_dtc_block(fp, DTFS_DIR_BLOCK, dir) != 0) {
        fclose(fp);
        fail("cannot read DTFS directory block");
    }
    if (dir[DTFS_MAGIC_WORD] != DTFS_NATIVE_MAGIC) {
        fclose(fp);
        fail("DTFS native magic mismatch");
    }
    if (dtfs_owner(dir, 0U) != DTFS_OWNER_RESERVED ||
        dtfs_owner(dir, DTFS_DIR_BLOCK) != DTFS_OWNER_RESERVED) {
        fclose(fp);
        fail("DTFS structural owner mismatch");
    }
    for (block = DTFS_BLOCKS; block <= 580U; ++block) {
        if (dtfs_owner(dir, block) != DTFS_OWNER_NATIVE_TAG) {
            fclose(fp);
            fail("DTFS native excess-map tag mismatch");
        }
    }
    for (block = 44U; block < DTFS_MAP_WORDS; ++block) {
        if ((dir[block] & 1U) != 0) {
            fclose(fp);
            fail("DTFS reserved sideband bit is nonzero");
        }
    }
    memset(chained, 0, sizeof chained);

    for (slot = 0U; slot < DTFS_FILE_SLOTS; ++slot) {
        unsigned int blocks = 0U;
        unsigned int first = 0U;
        unsigned int first_count = 0U;
        unsigned int last_words = dtfs_last_words(dir, slot);
        unsigned int current, chain_count;
        int present = dir[DTFS_NAME_BASE + slot * 2U] != 0;

        owner = slot + 1U;
        for (block = 1U; block <= DTFS_LAST_BLOCK; ++block) {
            if (dtfs_owner(dir, block) != owner)
                continue;
            ++blocks;
            if (read_dtc_block(fp, block, block_words) != 0) {
                fclose(fp);
                fail("cannot read DTFS owned data block");
            }
            if (dtfs_hdr_first(block_words[0]) == block) {
                first = block;
                ++first_count;
            }
        }
        if (!present) {
            if (blocks != 0U || last_words != 0U ||
                (dir[slot] & 1U) != 0 || (dir[22U + slot] & 1U) != 0) {
                fclose(fp);
                fail("DTFS empty slot retains allocation or sideband state");
            }
            continue;
        }
        if (blocks == 0U) {
            if (last_words != 0U) {
                fclose(fp);
                fail("DTFS empty file has nonzero LAST_WORDS");
            }
            continue;
        }
        if (last_words == 0U || last_words > DTFS_DATA_WORDS || first_count != 1U) {
            fclose(fp);
            fail("DTFS file size or first-block metadata invalid");
        }
        current = first;
        chain_count = 0U;
        for (;;) {
            unsigned int next, count;
            if (current == 0U || current > DTFS_LAST_BLOCK ||
                chained[current] != 0 || dtfs_owner(dir, current) != owner) {
                fclose(fp);
                fail("DTFS chain loop, cross-link, or owner mismatch");
            }
            chained[current] = 1;
            ++chain_count;
            if (read_dtc_block(fp, current, block_words) != 0) {
                fclose(fp);
                fail("cannot read DTFS chain block");
            }
            if (dtfs_hdr_first(block_words[0]) != first) {
                fclose(fp);
                fail("DTFS FIRST pointer mismatch");
            }
            next = dtfs_hdr_next(block_words[0]);
            count = dtfs_hdr_count(block_words[0]);
            if (next == 0U) {
                if (count != last_words) {
                    fclose(fp);
                    fail("DTFS final COUNT/LAST_WORDS mismatch");
                }
                break;
            }
            if (count != DTFS_DATA_WORDS || next > DTFS_LAST_BLOCK) {
                fclose(fp);
                fail("DTFS nonfinal COUNT or NEXT invalid");
            }
            current = next;
        }
        if (chain_count != blocks) {
            fclose(fp);
            fail("DTFS orphaned allocated block");
        }
    }

    for (block = 1U; block <= DTFS_LAST_BLOCK; ++block) {
        owner = dtfs_owner(dir, block);
        if (block == DTFS_DIR_BLOCK) {
            if (owner != DTFS_OWNER_RESERVED) {
                fclose(fp);
                fail("DTFS directory block is not reserved");
            }
            continue;
        }
        if (owner == DTFS_OWNER_FREE || owner == DTFS_OWNER_RESERVED)
            continue;
        if (owner > DTFS_FILE_SLOTS) {
            fclose(fp);
            fail("DTFS illegal owner value");
        }
        if (chained[block] == 0) {
            fclose(fp);
            fail("DTFS allocated block not reachable from a file chain");
        }
    }
    fclose(fp);
    puts("DAIMOS DTFS native media consistency test PASS");
    return 0;
}

static int
skip_bytes(FILE *fp, uint32_t n)
{
    unsigned char buf[4096];
    while (n != 0) {
        size_t chunk = n < sizeof buf ? n : sizeof buf;
        if (fread(buf, 1, chunk, fp) != chunk)
            return -1;
        n -= (uint32_t)chunk;
    }
    return 0;
}

static int
check_mtc(int argc, char **argv)
{
    FILE *fp;
    long wanted_record;
    char *end;
    long record = 0;
    unsigned char *data = NULL;
    uint32_t data_len = 0;
    int i;

    if (argc < 3)
        fail("mtc requires TAPE RECORD WORD...");
    wanted_record = strtol(argv[1], &end, 10);
    if (*argv[1] == '\0' || *end != '\0' || wanted_record < 0)
        fail("invalid MTC record");
    fp = fopen(argv[0], "rb");
    if (fp == NULL)
        fail("cannot open SIMH tape image");

    for (;;) {
        unsigned char raw[4], trailer[4];
        uint32_t n;
        if (fread(raw, 1, 4, fp) != 4) {
            fclose(fp);
            fail("missing written SIMH tape record");
        }
        n = le32(raw);
        if (record == wanted_record) {
            data_len = n;
            if (n != 0) {
                data = (unsigned char *)malloc(n);
                if (data == NULL) {
                    fclose(fp);
                    fail("out of memory");
                }
                if (fread(data, 1, n, fp) != n) {
                    free(data);
                    fclose(fp);
                    fail("short SIMH tape record");
                }
                if ((n & 1U) != 0 && fgetc(fp) == EOF) {
                    free(data);
                    fclose(fp);
                    fail("short SIMH tape pad");
                }
                if (fread(trailer, 1, 4, fp) != 4 || le32(trailer) != n) {
                    free(data);
                    fclose(fp);
                    fail("bad SIMH tape trailer");
                }
            }
            break;
        }
        if (n != 0) {
            if (skip_bytes(fp, n + (n & 1U)) != 0 || fread(trailer, 1, 4, fp) != 4 || le32(trailer) != n) {
                fclose(fp);
                fail("bad SIMH tape record");
            }
        }
        ++record;
    }
    fclose(fp);

    if ((data_len % 6U) != 0)
        fail("7-track record is not a whole number of words");
    if ((int)(data_len / 6U) != argc - 2)
        fail("MTC write word count mismatch");
    for (i = 0; i < argc - 2; ++i) {
        uint64_t got = 0;
        uint64_t want = parse_octal(argv[i + 2]);
        int j;
        for (j = 0; j < 6; ++j)
            got = (got << 6) | (uint64_t)(data[i * 6 + j] & 077U);
        if (got != want) {
            fprintf(stderr, "host-check-v1: MTC word %d got %012llo expected %012llo\n",
                    i, (unsigned long long)got, (unsigned long long)want);
            free(data);
            return 1;
        }
    }
    free(data);
    puts("PDP-6 MTC resident write test PASS");
    return 0;
}

static uint32_t
param_mode(unsigned int mode)
{
    return (mode & 07U) << 13;
}

static uint32_t
point_coord(int yflag, unsigned int coord, unsigned int next_mode)
{
    uint32_t value = (next_mode & 07U) << 13;
    if (yflag)
        value |= 0200000U;
    value |= coord & 01777U;
    return value & 0777777U;
}

static uint32_t
char3(unsigned int a, unsigned int b, unsigned int c)
{
    return ((a & 077U) << 12) | ((b & 077U) << 6) | (c & 077U);
}

static uint64_t
inst(uint32_t left, uint32_t right)
{
    return ((uint64_t)(left & 0777777U) << 18) | (uint64_t)(right & 0777777U);
}

static unsigned int
type342_code(char ch)
{
    unsigned int value = (unsigned char)ch;
    if (ch >= 'A' && ch <= 'Z')
        return value - (unsigned int)'A' + 1U;
    if (value >= 040U && value <= 077U)
        return value;
    return 077U;
}

static size_t
make_dpy_banner(const char *version, uint64_t *out, size_t cap)
{
    char text[128];
    unsigned int codes[128];
    size_t n, i, pos = 0, ci = 0;

    if (snprintf(text, sizeof text, "DAIMOS V%s  ", version) >= (int)sizeof text)
        fail("VERSION is too long");
    n = strlen(text);
    for (i = 0; i < n; ++i)
        codes[i] = type342_code(text[i]);
    if (cap < 3)
        fail("internal DPY buffer too small");
    out[pos++] = inst(param_mode(DPY_MODE_POINT), point_coord(0, 0240, DPY_MODE_POINT));
    out[pos++] = inst(point_coord(1, 01000, 0), param_mode(0));
    {
        unsigned int a = ci < n ? codes[ci++] : TYPE342_SPACE;
        unsigned int b = ci < n ? codes[ci++] : TYPE342_SPACE;
        unsigned int c = ci < n ? codes[ci++] : TYPE342_SPACE;
        out[pos++] = inst(param_mode(DPY_MODE_CHAR), char3(a, b, c));
    }
    while (ci < n) {
        unsigned int g[6];
        for (i = 0; i < 6; ++i)
            g[i] = ci < n ? codes[ci++] : TYPE342_SPACE;
        if (pos >= cap)
            fail("internal DPY buffer too small");
        out[pos++] = inst(char3(g[0], g[1], g[2]), char3(g[3], g[4], g[5]));
    }
    return pos;
}

static int
check_dpy(int argc, char **argv)
{
    FILE *fp;
    char version[64], line[1024];
    uint64_t expected[128];
    size_t count, seen = 0;

    if (argc != 2)
        fail("dpy requires DEBUG_LOG VERSION");
    read_version(argv[1], version, sizeof version);
    count = make_dpy_banner(version, expected, sizeof expected / sizeof expected[0]);
    fp = fopen(argv[0], "r");
    if (fp == NULL)
        fail("cannot open DPY debug log");
    while (fgets(line, sizeof line, fp) != NULL) {
        unsigned long long value;
        {
            const char *p = strstr(line, "DPY 131 DATO ");
            if (p != NULL && sscanf(p, "DPY 131 DATO %llo", &value) == 1) {
                if (seen >= count || (uint64_t)value != expected[seen]) {
                    fclose(fp);
                    fail("DPY banner DATAO mismatch");
                }
                ++seen;
            }
        }
    }
    fclose(fp);
    if (seen != count)
        fail("DPY banner DATAO count mismatch");
    puts("PDP-6 DPY DAIMOS version banner test PASS");
    return 0;
}

static uint64_t
version_glyph(char ch)
{
    if (ch >= '0' && ch <= '9')
        return wcnsls_digits[(unsigned int)(ch - '0')];
    if (ch == 'V')
        return WCNSLS_GLYPH_V;
    if (ch == '.')
        return WCNSLS_GLYPH_DOT;
    if (ch == '-')
        return WCNSLS_GLYPH_DASH;
    return 0;
}

static size_t
append_glyph_points(uint64_t glyph, unsigned int x, uint64_t *out, size_t pos, size_t cap)
{
    int row, col;
    for (row = 0; row < 7; ++row) {
        for (col = 0; col < 5; ++col) {
            int bit = 34 - row * 5 - col;
            if (((glyph >> bit) & 1U) != 0) {
                unsigned int px = x + (unsigned int)col * 7U;
                unsigned int py = 0330U - (unsigned int)row * 7U;
                if (pos >= cap)
                    fail("internal WCNSLS buffer too small");
                out[pos++] = (uint64_t)(((px & 0777U) << 9) | (py & 0777U));
            }
        }
    }
    return pos;
}

static size_t
make_wcnsls_banner(const char *version, uint64_t *out, size_t cap)
{
    unsigned int x = 025U;
    size_t pos = 0, i;
    char text[128];

    for (i = 0; i < sizeof wcnsls_title / sizeof wcnsls_title[0]; ++i) {
        pos = append_glyph_points(wcnsls_title[i], x, out, pos, cap);
        x += 42U;
    }
    if (snprintf(text, sizeof text, "V%s  ", version) >= (int)sizeof text)
        fail("VERSION is too long");
    for (i = 0; text[i] != '\0'; ++i) {
        pos = append_glyph_points(version_glyph(text[i]), x, out, pos, cap);
        x += 42U;
    }
    return pos;
}

static int
check_wcnsls(int argc, char **argv)
{
    FILE *fp;
    char version[64], line[1024];
    uint64_t expected[2048];
    size_t count, seen = 0;
    int cono_seen = 0, diag_seen = 0;

    if (argc != 3)
        fail("wcnsls requires DEBUG_LOG SIMH_LOG VERSION");
    read_version(argv[2], version, sizeof version);
    count = make_wcnsls_banner(version, expected, sizeof expected / sizeof expected[0]);
    fp = fopen(argv[0], "r");
    if (fp == NULL)
        fail("cannot open WCNSLS debug log");
    while (fgets(line, sizeof line, fp) != NULL) {
        unsigned int cono;
        unsigned long long value;
        {
            const char *p = strstr(line, "WCNSLS CONO: ");
            if (p != NULL && sscanf(p, "WCNSLS CONO: %o", &cono) == 1 && !cono_seen) {
                if (cono != WCNSLS_GREEN_CONO) {
                    fclose(fp);
                    fail("WCNSLS banner CONO mismatch");
                }
                cono_seen = 1;
            }
        }
        {
            const char *p = strstr(line, "WCNSLS DATAIO: DATAO ");
            if (p != NULL && sscanf(p, "WCNSLS DATAIO: DATAO %llo", &value) == 1) {
                if (seen >= count || (uint64_t)value != expected[seen]) {
                    fclose(fp);
                    fail("WCNSLS banner DATAO mismatch");
                }
                ++seen;
            }
        }
    }
    fclose(fp);
    if (!cono_seen)
        fail("WCNSLS banner CONO missing");
    if (seen != count)
        fail("WCNSLS banner DATAO count mismatch");

    fp = fopen(argv[1], "r");
    if (fp == NULL)
        fail("cannot open WCNSLS SIMH log");
    while (fgets(line, sizeof line, fp) != NULL) {
        size_t n = strlen(line);
        while (n > 0 && isspace((unsigned char)line[n - 1]))
            line[--n] = '\0';
        if (strcmp(line, "WCNSLS                            LOADED") == 0)
            diag_seen = 1;
    }
    fclose(fp);
    if (!diag_seen)
        fail("WCNSLS LOADED diagnostic missing");
    puts("PDP-6 WCNSLS color-scope DAIMOS version banner test PASS");
    return 0;
}

int
main(int argc, char **argv)
{
    if (argc < 2)
        fail("missing subcommand");
    if (strcmp(argv[1], "ptp") == 0)
        return check_ptp(argc - 2, argv + 2);
    if (strcmp(argv[1], "dtc") == 0)
        return check_dtc(argc - 2, argv + 2);
    if (strcmp(argv[1], "dtfs") == 0)
        return check_dtfs(argc - 2, argv + 2);
    if (strcmp(argv[1], "mtc") == 0)
        return check_mtc(argc - 2, argv + 2);
    if (strcmp(argv[1], "dpy") == 0)
        return check_dpy(argc - 2, argv + 2);
    if (strcmp(argv[1], "wcnsls") == 0)
        return check_wcnsls(argc - 2, argv + 2);
    fail("unknown subcommand");
    return 1;
}
