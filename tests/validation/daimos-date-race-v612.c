/* Native multiprocess GETTIME/SETTIME race under scheduler preemption. */
#include "dsys.h"
#define SIXCHAR(ch) (((unsigned long)(ch)-040UL)&077UL)
#define SIX6(a,b,c,d,e,f) ((SIXCHAR(a)<<30)|(SIXCHAR(b)<<24)| \
 (SIXCHAR(c)<<18)|(SIXCHAR(d)<<12)|(SIXCHAR(e)<<6)|SIXCHAR(f))
#define NP 3U
#define PW 3U
#define OFF SYS_RUN_V2_FIXED_WORDS
#define MAP (OFF+2U*PW)
#define SIZE (MAP+3U)
#define TIME(yy,mo,dd,hh,mm,ss) \
 (((kword_t)((((yy)/10U)<<4U)|((yy)%10U))<<26U)| \
 ((kword_t)(mo)<<22U)|((kword_t)(dd)<<17U)| \
 ((kword_t)(hh)<<12U)|((kword_t)(mm)<<6U)|(kword_t)(ss))
static kword_t path[PW]={12UL,SIX6('/','S','Y','S','T','E'),SIX6('M','/','I','N','I','T')};
static kword_t lo=TIME(28,2,29,23,59,58);
static kword_t hi=TIME(28,3,1,0,0,2);
static int spawn(void)
{
 kword_t b[SIZE]; struct sys_run_v2 *r=(struct sys_run_v2 *)b;
 unsigned int i;
 for(i=0U;i<SIZE;i++) b[i]=0UL;
 r->version_words=SYS_RUN_HEADER(SYS_RUN_VERSION_2,SIZE);
 r->flags=SYS_RUN_PGRP_INHERIT; r->argc=1UL; r->fdmap_count=3UL;
 for(i=0U;i<PW;i++){b[OFF+i]=path[i];b[OFF+PW+i]=path[i];}
 b[MAP]=SYS_RUN_FD_MAP(0U,0U);
 b[MAP+1U]=SYS_RUN_FD_MAP(1U,1U);
 b[MAP+2U]=SYS_RUN_FD_MAP(2U,2U);
 return dsys_run(r);
}
static int valid(kword_t t)
{
 unsigned int mo=(unsigned int)((t>>22U)&017UL);
 unsigned int d=(unsigned int)((t>>17U)&037UL);
 unsigned int h=(unsigned int)((t>>12U)&037UL);
 unsigned int m=(unsigned int)((t>>6U)&077UL);
 unsigned int s=(unsigned int)(t&077UL);
 return t>=lo && t<=(hi+4UL) &&
   ((mo==2U && d==29U)||(mo==3U && d==1U)) &&
   h<=23U && m<=59U && s<=59U;
}
int main(void)
{
 int pid[NP],ok=1,i,j; kword_t status,t;
 if(dsys_getpid()>1){
   for(j=0;j<100;j++){
     t=dsys_gettime();
     if(!valid(t)) { (void)dsys_exit(7);return 7; }
     (void)dsys_sleep(1U);
   }
   (void)dsys_exit(0);return 0;
 }
 (void)dsys_writechar(1,'#');
 if(dsys_gettime()!=0UL){(void)dsys_writechar(1,'T');(void)dsys_writechar(1,'#');(void)dsys_halt();return 0;}
 if(dsys_settime(lo)!=0)ok=0;
 for(i=0;i<(int)NP;i++){pid[i]=spawn();if(pid[i]<=1)ok=0;}
 for(j=0;j<100;j++){
   if(dsys_settime((j&1)?lo:hi)!=0)ok=0;
   t=dsys_gettime();if(!valid(t))ok=0;
   (void)dsys_sleep(1U);
 }
 for(i=0;i<(int)NP;i++)if(pid[i]>1){
   if(dsys_wait((unsigned int)pid[i],&status,0U)!=pid[i]||
      SYS_WAIT_STATUS_KIND(status)!=SYS_WAIT_EXITED||
      SYS_WAIT_STATUS_VALUE(status)!=0U)ok=0;
 }
 (void)dsys_writechar(1,ok?'Z':'!');
 (void)dsys_writechar(1,'#');
 (void)dsys_halt();return 0;
}
