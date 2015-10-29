/*
 more examples: http://apiexamples.com/c/time/nanosleep.html 
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <string.h>

void Usage (prog, message)
char *prog;
char *message;
{
   char *text = "%s\n\
   Usage: %s number\n\
           count of 10000000 nanosecond (= 1/100 second) intervals to sleep\n\
           Example 1: 100 = 0.1 second\n\
           Example 2: 500 = 0.5 second\n";
   fprintf (stderr, text, message, prog);
}

int main(argc, argv)
int argc;
char *argv[];
{
   int milisec = 0; /* length of time to sleep in miliseconds */
   struct timespec tim;
   tim.tv_sec = 0;

   if (argc == 1) {
      milisec = 500;  /* default value 500 - 0.5 seconds */
   } else if (argc == 2) {
      milisec = atoi(argv[1]);
      if (milisec == 0) {
         Usage (argv[0], "Expect integer between 1 - 999");
         return(1);
      }
   } else {
      Usage (argv[0], "Expect integer between 1 - 999");
      return(1);
   }
   
   tim.tv_nsec = milisec * 1000000L;

   if ( nanosleep(&tim , (struct timespec *)NULL) < 0 )   
   {
      printf("Nano sleep system call failed \n");
      Usage (argv[0], "Expect integer between 1 - 999");
      return(1);
   }

   /*
   printf("Nano sleep successfull \n");
   */

   return 0;
}
