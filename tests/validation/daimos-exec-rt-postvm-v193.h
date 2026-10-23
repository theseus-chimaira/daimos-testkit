/*
 * EXEC RT rollback after vm_space_create() (PDP-6 v193).
 *
 * This DXR2 file has the exact length and headers required by the loader:
 *   header (3) + D6LZ payload (1) + relocation bitmap (1) = 5 words.
 * Its single zero D6LZ control word provides no following literal, so the
 * decoder runs out of input only after the replacement VM is allocated.
 * The original process and any preexisting RT reservation must survive.
 *
 * Included only in stage 0 of the RT-owner test; uses its replace_with(),
 * fail(), and the libc's 36-bit kword_t definitions.
 */
#ifndef DAIMOS_EXEC_RT_POSTVM_V193_H
#define DAIMOS_EXEC_RT_POSTVM_V193_H

static void
make_bad_d6lz_image_v193(void)
{
        kword_t path[U_PATH_WORDS];
        kword_t image[5];
        int fd;

        if (u_s6_pack(path, U_PATH_WORDS, "/TEMP/BADLZ") != 0)
                fail('p');

        image[0] = (kword_t)0447062UL << 18U; /* SIXBIT DXR */
        image[1] = ((kword_t)1UL << 18U) | 0500000UL;
        image[2] = 0647022UL;                 /* text_words=0, TX2 */
        image[3] = 0UL;                       /* truncated D6LZ literals */
        image[4] = 0UL;                       /* one relocation-map word */

        fd = dsys_open(path, FILE_O_WRITE | FILE_O_CREAT | FILE_O_TRUNC);
        if (fd < 0)
                fail('q');
        if (dsys_write_words(fd, image, 5U) != 5 ||
            dsys_close(fd) != 0 || dsys_chmod(path, 0555U) != 0)
                fail('r');
}

static void
check_bad_d6lz_exec_v193(void)
{
        make_bad_d6lz_image_v193();

        /* No owner: new RT_REQUIRED claim must be undone after decoder
         * failure and vm_space_destroy(), not merely on header failure. */
        if (dsys_rtctl(SYS_RTCTL_DISABLE) != -1 ||
            replace_with("/TEMP/BADLZ") != -1 ||
            dsys_rtctl(SYS_RTCTL_DISABLE) != -1)
                fail('s');
        (void)dsys_writechar(1, 'c');

        /* Existing owner: no new reservation was claimed; unloading the
         * failed replacement VM must not release the existing owner. */
        if (dsys_rtctl(SYS_RTCTL_ENABLE) != 0 ||
            replace_with("/TEMP/BADLZ") != -1 ||
            dsys_rtctl(SYS_RTCTL_DISABLE) != 0)
                fail('t');
        (void)dsys_writechar(1, 'd');
}

#endif
