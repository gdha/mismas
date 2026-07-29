/* based on cratimeout.c from http://cracauer-forum.cons.org/forum/viewtopic.php?t=17 */
/* Basically, we changed milliseconds into seconds */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

#include <sys/types.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <signal.h>
#include <unistd.h>
#include <sys/resource.h>

static volatile pid_t cpid_cmd = 0;

/*
 * Note: only async-signal-safe functions should be called from signal handlers.
 * write(2) is safe; perror/fprintf are not. We use write() for error messages
 * inside handlers and keep them minimal.
 */
static void write_err(const char *msg)
{
    /* best-effort write to stderr — ignore return value in signal context */
    ssize_t rc = write(STDERR_FILENO, msg, strlen(msg));
    (void)rc;
}

static void onsigchld(int sig)
{
    (void)sig;
    int status;
    pid_t pid;

    pid = wait(&status);
    if (pid == -1) {
        write_err("wait failed\n");
        _exit(2);
    }

    if (WIFSIGNALED(status)) {
        /* Emulate signal exit, but suppress core dump */
        struct rlimit rlim;
        rlim.rlim_cur = 0;
        rlim.rlim_max = 0;
        if (setrlimit(RLIMIT_CORE, &rlim) == -1) {
            write_err("setrlimit failed, continuing\n");
        }
        kill(getpid(), WTERMSIG(status));
    } else {
        _exit(WEXITSTATUS(status));
    }
}

static void on_timeout(int sig)
{
    (void)sig;
    int ret;

    if (cpid_cmd == 0) {
        write_err("timeout: internal error 3\n");
        _exit(3);
    }

    /*
     * Ignore exit status — there may be a race where the child exited
     * between the timeout firing and now.
     */
    ret = kill(cpid_cmd, SIGTERM);
    if (ret == -1) {
        write_err("kill(SIGTERM) failed\n");
    } else {
        /*
         * Give the child 10 seconds to clean up, then force-kill it.
         * The SIGCHLD handler will exit this process once the child is gone.
         */
        sleep(10);
        kill(cpid_cmd, SIGKILL);
    }

    /* Wait for SIGCHLD handler to pick up the debris */
    for (;;)
        pause();
}

int main(int argc, char *argv[])
{
    long timeout;
    char *cmd;
    char *endptr;
    const char *progname = argv[0];

    if (argc < 3) {
        fprintf(stderr, "Usage: %s seconds cmd args\n", progname);
        exit(1);
    }

    errno = 0;
    timeout = strtol(argv[1], &endptr, 10);
    if (errno != 0 || endptr == argv[1] || *endptr != '\0') {
        fprintf(stderr, "%s: invalid timeout value '%s'\n", progname, argv[1]);
        exit(1);
    }
    if (timeout < 1) {
        fprintf(stderr, "%s: timeout < 1 doesn't make sense\n", progname);
        exit(1);
    }

    /* Advance past the timeout argument */
    argc--;
    argv++;

    cmd = argv[1];
    argc--;
    argv++;

    /* Use sigaction instead of signal() for well-defined handler semantics */
    struct sigaction sa_chld;
    memset(&sa_chld, 0, sizeof(sa_chld));
    sa_chld.sa_handler = onsigchld;
    sa_chld.sa_flags   = SA_RESTART;
    sigemptyset(&sa_chld.sa_mask);
    if (sigaction(SIGCHLD, &sa_chld, NULL) == -1) {
        perror("sigaction(SIGCHLD)");
        exit(1);
    }

    cpid_cmd = fork();
    if (cpid_cmd == -1) {
        perror("fork");
        exit(2);
    }

    if (cpid_cmd == 0) {
        /* Child: replace image with the requested command */
        execvp(cmd, argv);
        /* execvp only returns on error */
        fprintf(stderr, "%s: execvp '%s': %s\n", progname, cmd, strerror(errno));
        _exit(2);
    } else {
        /* Parent: arm the timeout via SIGALRM */
        struct sigaction sa_alrm;
        memset(&sa_alrm, 0, sizeof(sa_alrm));
        sa_alrm.sa_handler = on_timeout;
        sa_alrm.sa_flags   = SA_RESTART;
        sigemptyset(&sa_alrm.sa_mask);
        if (sigaction(SIGALRM, &sa_alrm, NULL) == -1) {
            perror("sigaction(SIGALRM)");
            exit(1);
        }

        struct itimerval itv;
        itv.it_interval.tv_sec  = (time_t)timeout;
        itv.it_interval.tv_usec = 0;
        itv.it_value.tv_sec     = (time_t)timeout;
        itv.it_value.tv_usec    = 0;
        if (setitimer(ITIMER_REAL, &itv, NULL) == -1) {
            perror("setitimer");
            exit(1);
        }

        for (;;)
            pause();
    }

    /* unreachable */
    return 0;
}
