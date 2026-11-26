#include "u.h"
#ifdef DAIMOS_RH18_WRAP_V1977
extern int rh18_probe_v1977(void);
#endif

int
main(int argc, kword_t **argv)
{
#ifdef DAIMOS_MUTABLE_MARK_V1976
        kword_t path[U_PATH_WORDS], header[3];
        int fd;
        if (u_s6_pack(path, U_PATH_WORDS, "/CONFIG/NATIVE.DXR") != 0)
                return 1;
        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0 || dsys_read_words(fd, header, 3U) != 3 ||
            dsys_close(fd) != 0 || (header[0] >> 18U) != 0447062UL ||
            (header[2] & 0777777UL) != 0647022UL ||
            !(header[2] & (0400000UL << 18U)) ||
            ((header[2] >> 18U) & 0377777UL) > (header[1] >> 18U))
                return 1;
        if (u_puts(1, "MUTABLE TX2 OK") != 0 || u_crlf(1) != 0)
                return 1;
#endif
#ifdef DAIMOS_RH18_WRAP_V1977
        if (rh18_probe_v1977() != 0 || u_puts(1, "RH18 WRAP OK") != 0 ||
            u_crlf(1) != 0)
                return 1;
#endif
        (void)argc;
        (void)argv;
        if (u_puts(1, "NATIVE LINK OK") != 0 || u_crlf(1) != 0)
                return 1;
        return 0;
}
