#define _XOPEN_SOURCE 600

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

static volatile sig_atomic_t child_pid;
static volatile sig_atomic_t stop_signal;

static void
forward_signal(int signo)
{
    pid_t pid = (pid_t)child_pid;

    stop_signal = signo;
    if (pid > 0)
        (void)kill(pid, signo);
}

static void
fatal(const char *what)
{
    fprintf(stderr, "pty-run-v1: %s: %s\n", what, strerror(errno));
    exit(1);
}

static int
write_all(int fd, const unsigned char *buf, size_t len)
{
    while (len != 0) {
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
child_status(pid_t pid)
{
    int status;

    while (waitpid(pid, &status, 0) < 0) {
        if (errno == EINTR)
            continue;
        fatal("waitpid");
    }
    child_pid = 0;
    if (WIFEXITED(status))
        return WEXITSTATUS(status);
    if (WIFSIGNALED(status))
        return 128 + WTERMSIG(status);
    return 1;
}

static int
terminate_child(pid_t pid)
{
    int i;
    int status;

    /* Give a normally terminating child a brief chance to honor the signal.
     * SIMH catches SIGTERM and returns to its monitor instead of exiting, so
     * the wrapper must not wait indefinitely after its own caller has asked
     * it to terminate. */
    for (i = 0; i < 10; ++i) {
        pid_t rc = waitpid(pid, &status, WNOHANG);
        if (rc == pid) {
            child_pid = 0;
            if (WIFEXITED(status))
                return WEXITSTATUS(status);
            if (WIFSIGNALED(status))
                return 128 + WTERMSIG(status);
            return 1;
        }
        if (rc < 0 && errno != EINTR)
            fatal("waitpid");
        (void)usleep(10000);
    }

    (void)kill(pid, SIGKILL);
    return child_status(pid);
}

int
main(int argc, char **argv)
{
    int master;
    char *slave_name;
    pid_t pid;
    int stdin_open = 1;
    int raw = 0;
    int argi = 1;
    struct sigaction sa;

    if (argc > 1 && strcmp(argv[1], "-r") == 0) {
        raw = 1;
        argi = 2;
    }
    if (argc <= argi) {
        fprintf(stderr, "usage: pty-run-v1 [-r] PROGRAM [ARG ...]\n");
        return 2;
    }

    master = posix_openpt(O_RDWR | O_NOCTTY);
    if (master < 0)
        fatal("posix_openpt");
    if (grantpt(master) < 0)
        fatal("grantpt");
    if (unlockpt(master) < 0)
        fatal("unlockpt");
    slave_name = ptsname(master);
    if (slave_name == NULL)
        fatal("ptsname");

    pid = fork();
    if (pid < 0)
        fatal("fork");
    if (pid == 0) {
        int slave;

        if (setsid() < 0)
            fatal("setsid");
        slave = open(slave_name, O_RDWR);
        if (slave < 0)
            fatal("open pty slave");
#ifdef TIOCSCTTY
        if (ioctl(slave, TIOCSCTTY, 0) < 0)
            fatal("TIOCSCTTY");
#endif
        if (raw) {
            struct termios tio;

            if (tcgetattr(slave, &tio) < 0)
                fatal("tcgetattr");
            tio.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
            tio.c_oflag &= ~OPOST;
            tio.c_cflag |= CS8;
            tio.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
            tio.c_cc[VMIN] = 1;
            tio.c_cc[VTIME] = 0;
            if (tcsetattr(slave, TCSANOW, &tio) < 0)
                fatal("tcsetattr");
        }
        if (dup2(slave, STDIN_FILENO) < 0 ||
            dup2(slave, STDOUT_FILENO) < 0 ||
            dup2(slave, STDERR_FILENO) < 0)
            fatal("dup2");
        if (slave > STDERR_FILENO)
            close(slave);
        close(master);
        execvp(argv[argi], &argv[argi]);
        fprintf(stderr, "pty-run-v1: exec %s: %s\n", argv[argi], strerror(errno));
        _exit(127);
    }

    child_pid = (sig_atomic_t)pid;
    memset(&sa, 0, sizeof sa);
    sa.sa_handler = forward_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    (void)sigaction(SIGTERM, &sa, NULL);
    (void)sigaction(SIGHUP, &sa, NULL);
    (void)sigaction(SIGINT, &sa, NULL);

    for (;;) {
        fd_set rfds;
        int maxfd = master;
        int rc;

        if (stop_signal != 0)
            return terminate_child(pid);
        FD_ZERO(&rfds);
        FD_SET(master, &rfds);
        if (stdin_open) {
            FD_SET(STDIN_FILENO, &rfds);
            if (STDIN_FILENO > maxfd)
                maxfd = STDIN_FILENO;
        }

        rc = select(maxfd + 1, &rfds, NULL, NULL, NULL);
        if (rc < 0) {
            if (errno == EINTR) {
                if (stop_signal != 0)
                    return terminate_child(pid);
                continue;
            }
            fatal("select");
        }

        if (stdin_open && FD_ISSET(STDIN_FILENO, &rfds)) {
            unsigned char buf[1024];
            ssize_t n = read(STDIN_FILENO, buf, sizeof buf);
            if (n > 0) {
                if (raw) {
                    ssize_t i;
                    for (i = 0; i < n; ++i) {
                        if (write_all(master, &buf[i], 1U) < 0 && errno != EIO)
                            fatal("write pty");
                        (void)usleep(100000U);
                    }
                } else if (write_all(master, buf, (size_t)n) < 0 &&
                    errno != EIO) {
                    fatal("write pty");
                }
            } else if (n == 0) {
                stdin_open = 0;
            } else if (errno != EINTR) {
                fatal("read stdin");
            }
        }

        if (FD_ISSET(master, &rfds)) {
            unsigned char buf[4096];
            ssize_t n = read(master, buf, sizeof buf);
            if (n > 0) {
                if (write_all(STDOUT_FILENO, buf, (size_t)n) < 0)
                    fatal("write stdout");
            } else if (n == 0 || (n < 0 && errno == EIO)) {
                close(master);
                return child_status(pid);
            } else if (errno != EINTR) {
                fatal("read pty");
            }
        }
    }
}
