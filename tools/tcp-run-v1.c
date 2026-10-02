#define _POSIX_C_SOURCE 200112L

#include <errno.h>
#include <netdb.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

static void
fatal(const char *what)
{
    fprintf(stderr, "tcp-run-v1: %s: %s\n", what, strerror(errno));
    exit(1);
}

static int
write_all(int fd, const unsigned char *buf, size_t len)
{
    while (len != 0U) {
        ssize_t n = write(fd, buf, len);
        if (n > 0) {
            buf += (size_t)n;
            len -= (size_t)n;
            continue;
        }
        if (n < 0 && errno == EINTR)
            continue;
        return -1;
    }
    return 0;
}

static int
connect_retry(const char *host, const char *port)
{
    struct addrinfo hints;
    struct addrinfo *ai;
    struct addrinfo *p;
    int fd;
    int rc;
    int attempt;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    rc = getaddrinfo(host, port, &hints, &ai);
    if (rc != 0) {
        fprintf(stderr, "tcp-run-v1: getaddrinfo: %s\n", gai_strerror(rc));
        exit(1);
    }
    for (attempt = 0; attempt < 600; ++attempt) {
        for (p = ai; p != NULL; p = p->ai_next) {
            fd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
            if (fd < 0)
                continue;
            if (connect(fd, p->ai_addr, p->ai_addrlen) == 0) {
                freeaddrinfo(ai);
                return fd;
            }
            close(fd);
        }
        {
            struct timespec ts;
            ts.tv_sec = 0;
            ts.tv_nsec = 50000000L;
            (void)nanosleep(&ts, NULL);
        }
    }
    freeaddrinfo(ai);
    errno = ETIMEDOUT;
    fatal("connect");
    return -1;
}

int
main(int argc, char **argv)
{
    int fd;
    int stdin_open;

    if (argc != 3) {
        fprintf(stderr, "usage: tcp-run-v1 HOST PORT\n");
        return 2;
    }
    (void)signal(SIGPIPE, SIG_IGN);
    fd = connect_retry(argv[1], argv[2]);
    stdin_open = 1;
    for (;;) {
        fd_set rfds;
        int maxfd;
        int rc;

        FD_ZERO(&rfds);
        FD_SET(fd, &rfds);
        maxfd = fd;
        if (stdin_open) {
            FD_SET(STDIN_FILENO, &rfds);
            if (STDIN_FILENO > maxfd)
                maxfd = STDIN_FILENO;
        }
        rc = select(maxfd + 1, &rfds, NULL, NULL, NULL);
        if (rc < 0) {
            if (errno == EINTR)
                continue;
            fatal("select");
        }
        if (stdin_open && FD_ISSET(STDIN_FILENO, &rfds)) {
            unsigned char buf[512];
            ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
            if (n > 0) {
                if (write_all(fd, buf, (size_t)n) != 0)
                    fatal("write socket");
            } else if (n == 0) {
                stdin_open = 0;
                (void)shutdown(fd, SHUT_WR);
            } else if (errno != EINTR) {
                fatal("read stdin");
            }
        }
        if (FD_ISSET(fd, &rfds)) {
            unsigned char buf[2048];
            ssize_t n = read(fd, buf, sizeof(buf));
            if (n > 0) {
                if (write_all(STDOUT_FILENO, buf, (size_t)n) != 0)
                    fatal("write stdout");
            } else if (n == 0) {
                close(fd);
                return 0;
            } else if (errno != EINTR) {
                fatal("read socket");
            }
        }
    }
}
