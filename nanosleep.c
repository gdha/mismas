/*
 more examples: http://apiexamples.com/c/time/nanosleep.html
*/

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <string.h>
#include <errno.h>

static void usage(const char *prog, const char *message)
{
    fprintf(stderr,
        "%s\n"
        "   Usage: %s number\n"
        "           count of 10000000 nanosecond (= 1/100 second) intervals to sleep\n"
        "           Example 1: 100 = 0.1 second\n"
        "           Example 2: 500 = 0.5 second\n",
        message, prog);
}

int main(int argc, char *argv[])
{
    long milisec = 0; /* length of time to sleep in milliseconds (up to 999) */
    struct timespec tim;
    tim.tv_sec = 0;

    if (argc == 1) {
        milisec = 500;  /* default value 500 = 0.5 seconds */
    } else if (argc == 2) {
        char *endptr;
        errno = 0;
        milisec = strtol(argv[1], &endptr, 10);
        if (errno != 0 || endptr == argv[1] || *endptr != '\0') {
            usage(argv[0], "Expect integer between 1 - 999");
            return 1;
        }
        if (milisec < 1 || milisec > 999) {
            usage(argv[0], "Expect integer between 1 - 999");
            return 1;
        }
    } else {
        usage(argv[0], "Expect integer between 1 - 999");
        return 1;
    }

    /* milisec is guaranteed [1, 999] so tv_nsec stays within [0, 999000000] */
    tim.tv_nsec = milisec * 1000000L;

    if (nanosleep(&tim, NULL) < 0) {
        fprintf(stderr, "nanosleep failed: %s\n", strerror(errno));
        return 1;
    }

    return 0;
}
