/* Verify MEMFS timestamps use shared software UTC following SETTIME. */
#include "u.h"
#ifndef WALL_CLOCK_HZ
#error Frequency required
#endif
#define TIME36(yy,mo,dd,hh,mm,ss) \
 ((((kword_t)((((yy)/10U)<<4U)|((yy)%10U)))<<26U) | \
 ((kword_t)(mo)<<22U) | ((kword_t)(dd)<<17U) | \
 ((kword_t)(hh)<<12U) | ((kword_t)(mm)<<6U) | (kword_t)(ss))
int main(void)
{
    kword_t path[U_PATH_WORDS];
    struct vfs_stat st;
    kword_t t = TIME36(28,2,29,23,59,58);
    kword_t next = TIME36(28,3,1,0,0,0);
    kword_t x = 012345670UL;
    int fd, ok = 1;
    int has_pclk = dsys_gettime() != 0UL;
    (void)dsys_writechar(1, '#');
    if (u_s6_pack(path,U_PATH_WORDS,"/TEMP/CLKMTIME.TEST") != 0)
        ok = 0;
    if (!has_pclk && dsys_settime(t) != 0)
        ok = 0;
    fd = dsys_open(path,SYS_O_RDWR|SYS_O_CREAT|SYS_O_TRUNC);
    if (fd < 0) ok = 0;
    if (fd >= 0) {
        if (dsys_write_words(fd,&x,1U) != 1) ok = 0;
        if (dsys_close(fd) != 0) ok = 0;
        if (dsys_stat(path,&st) != 0 || st.mtime == 0UL) ok = 0;
        if (!has_pclk && st.mtime < t) ok = 0;
        if (!has_pclk) {
            if (dsys_sleep(3U*WALL_CLOCK_HZ) < 0) ok = 0;
            fd = dsys_open(path,SYS_O_RDWR);
            if (fd < 0 || dsys_write_words(fd,&x,1U) != 1 ||
                dsys_close(fd) != 0) ok = 0;
            if (dsys_stat(path,&st) != 0 || st.mtime < next) ok = 0;
        }
    }
    (void)dsys_writechar(1,ok ? (has_pclk ? 'T' : 'Z') : '!');
    (void)dsys_writechar(1,'#');
    (void)dsys_halt();
    return 0;
}
