/* Controlled physical pressure from PID1, independently of DSH RUN I/O.
 * Start the genuine shell on CTY, leave time for host SET, then RUN the
 * large unmarked child while DSH is blocked on terminal input. */
#include "dsys.h"
#define S6(c) (((kword_t)(c)-040UL)&077UL)
#define SIX(a,b,c,d,e,f) ((S6(a)<<30)|(S6(b)<<24)|(S6(c)<<18)|(S6(d)<<12)|(S6(e)<<6)|S6(f))
static kword_t shell_path[]={16UL,SIX('/','S','Y','S','T','E'),SIX('M','/','E','X','E','C'),SIX('/','D','S','H',' ',' ')};
static kword_t hold_path[]={17UL,SIX('/','S','Y','S','T','E'),SIX('M','/','E','X','E','C'),SIX('/','K','1','5','H',' ')};
static void say(const char *s)
{
        while(*s) (void)dsys_writechar(1,*s++);
}
static int spawn(kword_t *path,int fd)
{
        kword_t block[17];
        struct sys_run_v2 *r=(struct sys_run_v2 *)block;
        unsigned int i;
        for(i=0U;i<17U;++i) block[i]=0UL;
        r->version_words=SYS_RUN_HEADER(SYS_RUN_VERSION_2,17U);
        r->fdmap_count=3U; r->argc=1U;
        for(i=0U;i<4U;++i) block[6U+i]=block[10U+i]=path[i];
        block[14]=SYS_RUN_FD_MAP(0,fd);
        block[15]=SYS_RUN_FD_MAP(1,1);
        block[16]=SYS_RUN_FD_MAP(2,2);
        return dsys_run(r);
}
static int wait57(int pid)
{
        kword_t status=0UL;
        return dsys_wait((unsigned int)pid,&status,0U)==pid &&
            SYS_WAIT_STATUS_KIND(status)==SYS_WAIT_EXITED &&
            SYS_WAIT_STATUS_VALUE(status)==57U;
}
int main(void)
{
        kword_t p;
        int shell,child,rd,wr,pgrp;
        say("K15BOOT\r\n");
        /* Match LOGIN's controlling-terminal contract. PID1 is the
         * session leader; the shell inherits its foreground group. */
        if(dsys_procctl(SYS_PROCCTL_NEWSESSION,0U)<0 ||
            dsys_procctl(SYS_PROCCTL_TTY_ATTACH,0U)!=0) {
                say("K15TTYFAIL\r\n"); return 8;
        }
        pgrp=dsys_procctl(SYS_PROCCTL_GETPGRP,0U);
        if(pgrp<0 || dsys_procctl(SYS_PROCCTL_TTY_SETFG,(unsigned int)pgrp)!=pgrp ||
            dsys_procctl(SYS_PROCCTL_TTY_SETMODE,SYS_TTY_MODE_COOKED)!=SYS_TTY_MODE_COOKED) {
                say("K15FGFAIL\r\n"); return 9;
        }

        if((shell=spawn(shell_path,0))<0) { say("K15DSHFAIL\r\n"); return 1; }
        if(dsys_sleep(1200U)!=0) return 2;
        p=dsys_pipe();
        if(p==~0UL) return 3;
        rd=(int)(p>>18); wr=(int)(p&0777777UL);
        child=spawn(hold_path,rd);
        if(child<0) { say("K15RUNFAIL\r\n"); return 4; }
        if(dsys_close(rd)!=0) return 5;
        say("K15HELD\r\n");
        if(dsys_sleep(1200U)!=0 || dsys_close(wr)!=0 || !wait57(child)) return 6;
        say("K15REAPED\r\n");
        if(!wait57(shell)) return 7;
        say("K15DONE\r\n");
        (void)dsys_halt();
        return 0;
}
