/* based on cratimeout.c from http://cracauer-forum.cons.org/forum/viewtopic.php?t=17 */
/* Basically, we changed milleseconds into seconds */
#include <stdio.h>
#include <stdlib.h>

#include <sys/types.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <signal.h>
#include <unistd.h>
#include <sys/resource.h>

volatile pid_t cpid_cmd = 0;

void onsigchld(int sig)
{
  int exitstatus;
  pid_t pid;

  pid = wait(&exitstatus);
  if (pid == -1) {
    perror("wait");
    exit(2);
  }

  /* fprintf(stderr, "pid %d returned %d\n", pid, exitstatus); */

  if (WIFSIGNALED(exitstatus)) {
    /* Emulate signal exit, but don't dump core */
    struct rlimit rlim;
    rlim.rlim_cur = 0;
    rlim.rlim_max = 0;
    
    if (setrlimit(RLIMIT_CORE, &rlim) == -1) {
      perror("rlimit - continuing");
    }
    kill(getpid(), WTERMSIG(exitstatus));
  } else {
    exit(WEXITSTATUS(exitstatus));
  }
}

void on_timeout(int sig)
{
  int ret;

  if (cpid_cmd == 0) {
    fprintf(stderr, "timeout internal error 3\n");
    exit(3);
  } else {
    /*
     * Ignore exit status, might be a race condition and it exited
     * between triggering the timeout and now.
     */
    ret = kill(cpid_cmd, SIGTERM);
    if (ret == -1) {
      perror("kill");
    } else {
      /*
       * This will not be executed if the child gracefully exits.
       * Because the sigchld handler will exit this process.
       */
      sleep(10);
      kill(cpid_cmd, SIGKILL);
    }

    /* Wait for sigchld handler to pick up the debris */
    for (;;)
      pause();
  }
}

int main(int argc, char *argv[])
{
  int timeout;
  char *cmd;

  if (argc < 3) {
    fprintf(stderr, "Usage: %s seconds cmd args\n", argv[0]);
    exit(1);
  }
  timeout = atoi(argv[1]);
  if (timeout < 1) {
    fprintf(stderr, "%s: timeout < 1 doesn't make sense\n", argv[0]);
    exit(1);
  }
  argc--;
  argv++;

  cmd = argv[1];
  argc--;
  argv++;
 
  if (signal(SIGCHLD, onsigchld) == SIG_ERR) {
    perror("signal\n");
    exit(1);
  }
 
  cpid_cmd = fork();
  if (cpid_cmd == -1) {
    perror("fork");
    exit(2);
  }

  if (cpid_cmd == 0) {
    // Child become cmd
    if (execvp(cmd, argv) == -1) {
      perror("execvp");
      exit(2);
    } else {
      fprintf(stderr, "%s internal error 1\n", argv[0]);
      exit(3);
    }
  } else {
    // Parent sets timeout
    struct itimerval itv;
    signal(SIGALRM, on_timeout);
    itv.it_interval.tv_sec = timeout;
    itv.it_interval.tv_usec = 0;
    itv.it_value.tv_sec = timeout;
    itv.it_value.tv_usec = 0;
    setitimer(ITIMER_REAL, &itv, NULL);
    for (;;)
      pause();
    /* fprintf(stderr, "%s internal error 2\n", argv[0]);
     * exit(3);
     */
  }
}
