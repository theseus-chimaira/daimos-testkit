#include "dsys.h"

#define PATH_WORDS 4U
#define FILE_COUNT 25U

static kword_t dir_path[PATH_WORDS];
static kword_t file_path[PATH_WORDS];

static void
put_text(const char *s)
{
    while (*s != 0) {
        (void)dsys_writechar(1, (int)(unsigned char)*s);
        ++s;
    }
}

static void
put_dec2(unsigned int n)
{
    (void)dsys_writechar(1, (int)('0' + (n / 10U) % 10U));
    (void)dsys_writechar(1, (int)('0' + n % 10U));
}

static void
fail(char stage, unsigned int n)
{
    put_text("D6FS DIRECTORY GROW FAIL ");
    (void)dsys_writechar(1, stage);
    put_text(" ");
    put_dec2(n);
    put_text("\r\n");
    (void)dsys_halt();
}

static int
pack_sixbit(kword_t *dst, unsigned int cap, const char *s)
{
    unsigned int n;
    unsigned int i;
    unsigned int wi;
    unsigned int sh;
    unsigned int code;

    n = 0U;
    while (s[n] != 0)
        ++n;
    if (1U + (n + 5U) / 6U > cap)
        return -1;
    for (i = 0U; i < cap; ++i)
        dst[i] = 0UL;
    dst[0] = (kword_t)n;
    for (i = 0U; i < n; ++i) {
        if ((unsigned char)s[i] < 040U || (unsigned char)s[i] > 0137U)
            return -1;
        code = (unsigned int)(unsigned char)s[i] - 040U;
        wi = 1U + i / 6U;
        sh = 30U - (i % 6U) * 6U;
        dst[wi] |= (kword_t)code << sh;
    }
    return 0;
}

static int
make_file_path(unsigned int n)
{
    char text[14];
    const char prefix[] = "/TEMP/D/F";
    unsigned int i;

    for (i = 0U; prefix[i] != 0; ++i)
        text[i] = prefix[i];
    text[i++] = (char)('0' + (n / 10U) % 10U);
    text[i++] = (char)('0' + n % 10U);
    text[i] = 0;
    return pack_sixbit(file_path, PATH_WORDS, text);
}

int
main(void)
{
    unsigned int i;
    int fd;

    if (pack_sixbit(dir_path, PATH_WORDS, "/TEMP/D") != 0 ||
        dsys_mkdir(dir_path) != 0)
        fail('D', 0U);

    for (i = 0U; i < FILE_COUNT; ++i) {
        put_text("D6FS DIRECTORY CREATE ");
        put_dec2(i);
        put_text("\r\n");
        if (make_file_path(i) != 0)
            fail('P', i);
        fd = dsys_open(file_path, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
            fail('O', i);
        if (dsys_close(fd) != 0)
            fail('C', i);
    }

    put_text("D6FS DIRECTORY GROW PASS\r\n");
    (void)dsys_halt();
    return 0;
}
