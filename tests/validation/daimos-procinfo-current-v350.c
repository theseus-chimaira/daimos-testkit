/* Minimal no-child native PROCINFO UUO baseline, C99. */
#include "dsys.h"
static void mark(int c) { (void)dsys_writechar(1,c); }
int main(void) {
    struct sys_procinfo info;
    int rc;
    mark('<');
    rc=dsys_procinfo(1U,&info);
    mark('A');
    if(rc!=0 || info.pid!=1UL) {mark('!');dsys_exit(1);return 1;}
    mark('H');
    dsys_exit(0);
    return 0;
}
