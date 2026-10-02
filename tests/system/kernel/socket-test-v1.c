/* Socket-backed functional checks for DAIMOS PDP-6 DCS and GE drivers. */
#define _POSIX_C_SOURCE 200809L
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define CONNECT_SECONDS 15
#define EXIT_SECONDS 12
#define BUF_SIZE 8192

static void
fail(const char *msg)
{
    fprintf(stderr, "socket-test-v1: %s\n", msg);
    exit(1);
}

static void
sleep_ms(long ms)
{
    struct timespec ts;
    ts.tv_sec = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    while (nanosleep(&ts, &ts) != 0 && errno == EINTR)
        ;
}

static char *
read_file(const char *path, size_t *size_out)
{
    FILE *fp;
    long size;
    char *buf;

    fp = fopen(path, "rb");
    if (fp == NULL)
        fail("cannot open input file");
    if (fseek(fp, 0, SEEK_END) != 0 || (size = ftell(fp)) < 0 ||
        fseek(fp, 0, SEEK_SET) != 0) {
        fclose(fp);
        fail("cannot size input file");
    }
    buf = (char *)malloc((size_t)size + 1U);
    if (buf == NULL) {
        fclose(fp);
        fail("out of memory");
    }
    if (fread(buf, 1, (size_t)size, fp) != (size_t)size) {
        free(buf);
        fclose(fp);
        fail("cannot read input file");
    }
    fclose(fp);
    buf[size] = '\0';
    if (size_out != NULL)
        *size_out = (size_t)size;
    return buf;
}

static char *
replace_once(char *input, const char *needle, const char *replacement)
{
    char *at;
    size_t before, oldlen, newlen, tail;
    char *out;

    at = strstr(input, needle);
    if (at == NULL)
        fail("base INI is missing required text");
    before = (size_t)(at - input);
    oldlen = strlen(needle);
    newlen = strlen(replacement);
    tail = strlen(at + oldlen);
    out = (char *)malloc(before + newlen + tail + 1U);
    if (out == NULL)
        fail("out of memory");
    memcpy(out, input, before);
    memcpy(out + before, replacement, newlen);
    memcpy(out + before + newlen, at + oldlen, tail + 1U);
    free(input);
    return out;
}

static unsigned short
free_port(void)
{
    int fd;
    struct sockaddr_in addr;
    socklen_t len = sizeof addr;

    fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0)
        fail("socket failed");
    memset(&addr, 0, sizeof addr);
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = 0;
    if (bind(fd, (struct sockaddr *)&addr, sizeof addr) != 0 ||
        getsockname(fd, (struct sockaddr *)&addr, &len) != 0) {
        close(fd);
        fail("cannot allocate loopback port");
    }
    close(fd);
    return ntohs(addr.sin_port);
}

static int
connect_retry(unsigned short port, pid_t child)
{
    int ticks = CONNECT_SECONDS * 10;
    while (ticks-- > 0) {
        int fd;
        struct sockaddr_in addr;
        int status;

        if (waitpid(child, &status, WNOHANG) == child)
            return -1;
        fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0)
            fail("socket failed");
        memset(&addr, 0, sizeof addr);
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        addr.sin_port = htons(port);
        if (connect(fd, (struct sockaddr *)&addr, sizeof addr) == 0)
            return fd;
        close(fd);
        sleep_ms(100);
    }
    return -1;
}

static int
recv_append(int fd, unsigned char *buf, size_t *len, size_t cap)
{
    fd_set rfds;
    struct timeval tv;
    ssize_t n;

    if (*len == cap)
        return 0;
    FD_ZERO(&rfds);
    FD_SET(fd, &rfds);
    tv.tv_sec = 0;
    tv.tv_usec = 100000;
    if (select(fd + 1, &rfds, NULL, NULL, &tv) <= 0)
        return 0;
    n = recv(fd, buf + *len, cap - *len, 0);
    if (n > 0) {
        *len += (size_t)n;
        return 1;
    }
    return 0;
}

static int
contains(const unsigned char *buf, size_t len, const char *needle)
{
    size_t nlen = strlen(needle), i;
    if (nlen == 0)
        return 1;
    if (nlen > len)
        return 0;
    for (i = 0; i + nlen <= len; ++i)
        if (memcmp(buf + i, needle, nlen) == 0)
            return 1;
    return 0;
}

static void
drain(int fd, unsigned char *buf, size_t *len, size_t cap)
{
    int quiet = 3;
    while (quiet > 0) {
        if (recv_append(fd, buf, len, cap))
            quiet = 3;
        else
            --quiet;
    }
}

static pid_t
start_simh(const char *simh, const char *ini, const char *log)
{
    pid_t pid = fork();
    if (pid < 0)
        fail("fork failed");
    if (pid == 0) {
        int fd = open(log, O_WRONLY | O_CREAT | O_TRUNC, 0666);
        const char *stdbuf = getenv("STDBUF");
        if (fd < 0)
            _exit(126);
        if (dup2(fd, STDOUT_FILENO) < 0 || dup2(fd, STDERR_FILENO) < 0)
            _exit(126);
        close(fd);
        if (stdbuf == NULL || *stdbuf == '\0')
            stdbuf = "stdbuf";
        execlp(stdbuf, stdbuf, "-o0", "-e0", simh, ini, (char *)NULL);
        _exit(127);
    }
    return pid;
}

static void
wait_child(pid_t child)
{
    int ticks = EXIT_SECONDS * 10;
    int status;
    while (ticks-- > 0) {
        pid_t got = waitpid(child, &status, WNOHANG);
        if (got == child) {
            if (!WIFEXITED(status) || WEXITSTATUS(status) != 0)
                fail("simulator exited unsuccessfully");
            return;
        }
        if (got < 0)
            fail("waitpid failed");
        sleep_ms(100);
    }
    kill(child, SIGKILL);
    waitpid(child, &status, 0);
    fail("simulator did not finish");
}

static void
append_socket_log(const char *path, const char *label,
                  const unsigned char *buf, size_t len)
{
    FILE *fp = fopen(path, "ab");
    if (fp == NULL)
        fail("cannot append socket log");
    fprintf(fp, "\n--- %s ---\n", label);
    if (len != 0 && fwrite(buf, 1, len, fp) != len) {
        fclose(fp);
        fail("cannot append socket output");
    }
    fclose(fp);
}

static void
check_simh_log(const char *path, int want_ge)
{
    size_t len;
    char *text = read_file(path, &len);
    (void)len;
    if (strstr(text, "DCS                                   OK") == NULL) {
        free(text);
        fail("DCS MINIT diagnostic missing");
    }
    if (want_ge && strstr(text, "GE                                    OK") == NULL) {
        free(text);
        fail("GE MINIT diagnostic missing");
    }
    if (strstr(text, "DEVICE TEST OK") == NULL) {
        free(text);
        fail("device diagnostic did not finish");
    }
    free(text);
}

static void
write_ini(const char *path, const char *text)
{
    FILE *fp = fopen(path, "wb");
    size_t len = strlen(text);
    if (fp == NULL)
        fail("cannot create temporary INI");
    if (fwrite(text, 1, len, fp) != len || fclose(fp) != 0)
        fail("cannot write temporary INI");
}

static int
test_dcs(const char *simh, const char *base_ini, const char *log,
         const char *tmpdir)
{
    char *text = read_file(base_ini, NULL);
    char attach[256], ini[1024];
    unsigned short port = free_port();
    pid_t child;
    int dcs0 = -1, dcs1 = -1;
    unsigned char out0[BUF_SIZE], out1[BUF_SIZE];
    size_t n0 = 0, n1 = 0;
    int ticks;

    text = replace_once(text, "set dcs disabled", "set dcs enabled\nset dcs lines=8");
    snprintf(attach, sizeof attach,
             "attach -U dcs 127.0.0.1:%u\nexpect HALTAFTER=0 \"DEVICE TEST OK\" exit\ngo 020",
             (unsigned int)port);
    text = replace_once(text, "go 020", attach);
    snprintf(ini, sizeof ini, "%s/daimos-dcs-socket-v1-%ld.ini", tmpdir, (long)getpid());
    write_ini(ini, text);
    free(text);
    child = start_simh(simh, ini, log);
    dcs0 = connect_retry(port, child);
    if (dcs0 < 0) {
        kill(child, SIGKILL); waitpid(child, NULL, 0); unlink(ini);
        fail("could not connect DCS line 0");
    }
    sleep_ms(150);
    dcs1 = connect_retry(port, child);
    if (dcs1 < 0) {
        close(dcs0); kill(child, SIGKILL); waitpid(child, NULL, 0); unlink(ini);
        fail("could not connect DCS line 1");
    }
    sleep_ms(150);
    if (send(dcs1, "R", 1, 0) != 1)
        fail("cannot send DCS input");
    ticks = CONNECT_SECONDS * 10;
    while (ticks-- > 0 && !contains(out1, n1, "DAIMOS DCS1 OK"))
        recv_append(dcs1, out1, &n1, sizeof out1);
    wait_child(child);
    drain(dcs0, out0, &n0, sizeof out0);
    drain(dcs1, out1, &n1, sizeof out1);
    close(dcs1); close(dcs0); unlink(ini);
    append_socket_log(log, "DCS LINE 0", out0, n0);
    append_socket_log(log, "DCS LINE 1", out1, n1);
    check_simh_log(log, 0);
    if (contains(out0, n0, "DAIMOS DCS1 OK"))
        fail("line-1 output was misrouted to DCS line 0");
    if (!contains(out1, n1, "DAIMOS DCS1 OK"))
        fail("DCS line-1 socket output missing");
    puts("PDP-6 DCS socket test PASS");
    return 0;
}

static int
test_ge(const char *simh, const char *base_ini, const char *log,
        const char *tmpdir)
{
    char *text = read_file(base_ini, NULL);
    char attach[384], ini[1024];
    unsigned short dcs_port = free_port(), ge_port = free_port();
    pid_t child;
    int dcs0 = -1, dcs1 = -1, ge0 = -1, ge1 = -1;
    unsigned char d0[BUF_SIZE], d1[BUF_SIZE], g0[BUF_SIZE], g1[BUF_SIZE];
    size_t nd0 = 0, nd1 = 0, ng0 = 0, ng1 = 0;
    int ticks;

    text = replace_once(text, "set dcs disabled", "set dcs enabled\nset dcs lines=8");
    text = replace_once(text, "set ge disabled", "set ge enabled");
    snprintf(attach, sizeof attach,
             "attach -U dcs 127.0.0.1:%u\nattach -U ge 127.0.0.1:%u\n"
             "expect HALTAFTER=0 \"DEVICE TEST OK\" exit\ngo 020",
             (unsigned int)dcs_port, (unsigned int)ge_port);
    text = replace_once(text, "go 020", attach);
    snprintf(ini, sizeof ini, "%s/daimos-ge-socket-v1-%ld.ini", tmpdir, (long)getpid());
    write_ini(ini, text);
    free(text);
    child = start_simh(simh, ini, log);
    dcs0 = connect_retry(dcs_port, child);
    if (dcs0 < 0) goto connect_fail;
    sleep_ms(100);
    dcs1 = connect_retry(dcs_port, child);
    if (dcs1 < 0) goto connect_fail;
    ge0 = connect_retry(ge_port, child);
    if (ge0 < 0) goto connect_fail;
    sleep_ms(100);
    ge1 = connect_retry(ge_port, child);
    if (ge1 < 0) goto connect_fail;
    sleep_ms(150);
    if (send(dcs1, "R", 1, 0) != 1 || send(ge1, "G", 1, 0) != 1)
        fail("cannot send DCS/GE input");
    ticks = CONNECT_SECONDS * 10;
    while (ticks-- > 0 &&
           (!contains(d1, nd1, "DAIMOS DCS1 OK") ||
            !contains(g1, ng1, "DAIMOS GE1 OK"))) {
        recv_append(dcs1, d1, &nd1, sizeof d1);
        recv_append(ge1, g1, &ng1, sizeof g1);
    }
    wait_child(child);
    drain(dcs0, d0, &nd0, sizeof d0); drain(dcs1, d1, &nd1, sizeof d1);
    drain(ge0, g0, &ng0, sizeof g0); drain(ge1, g1, &ng1, sizeof g1);
    close(dcs0); close(dcs1); close(ge0); close(ge1); unlink(ini);
    append_socket_log(log, "DCS0", d0, nd0); append_socket_log(log, "DCS1", d1, nd1);
    append_socket_log(log, "GE0", g0, ng0); append_socket_log(log, "GE1", g1, ng1);
    check_simh_log(log, 1);
    if (!contains(d1, nd1, "DAIMOS DCS1 OK"))
        fail("DCS line-1 output missing");
    if (!contains(g1, ng1, "DAIMOS GE1 OK"))
        fail("GE line-1 output missing");
    if (contains(d0, nd0, "DAIMOS DCS1 OK") || contains(g0, ng0, "DAIMOS GE1 OK"))
        fail("terminal output misrouted");
    puts("PDP-6 shared DCS/GE PI4 socket test PASS");
    return 0;

connect_fail:
    if (dcs0 >= 0)
        close(dcs0);
    if (dcs1 >= 0)
        close(dcs1);
    if (ge0 >= 0)
        close(ge0);
    if (ge1 >= 0)
        close(ge1);
    kill(child, SIGKILL); waitpid(child, NULL, 0); unlink(ini);
    fail("could not connect DCS/GE socket");
    return 1;
}

int
main(int argc, char **argv)
{
    const char *tmpdir;
    if (argc != 5)
        fail("usage: socket-test-v1 dcs|ge SIMH BASE_INI LOG");
    tmpdir = getenv("TMPDIR");
    if (tmpdir == NULL || *tmpdir == '\0')
        fail("TMPDIR must be set");
    if (strcmp(argv[1], "dcs") == 0)
        return test_dcs(argv[2], argv[3], argv[4], tmpdir);
    if (strcmp(argv[1], "ge") == 0)
        return test_ge(argv[2], argv[3], argv[4], tmpdir);
    fail("unknown socket test");
    return 1;
}
