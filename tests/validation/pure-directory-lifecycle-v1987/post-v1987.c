/* Independently linked unmarked replacement. The parent checks its
 * distinct exit status and the observer checks the unchanged PID. */
#include "dsys.h"
int main(int argc,kword_t **argv)
{
        (void)argv;
        if(argc!=1 || dsys_getpid()!=3) return 075;
        (void)dsys_writechar(1,'X');
        return 056;
}
