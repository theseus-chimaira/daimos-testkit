/* Native PDP-6 bounded decoder: corrupt streams must write NOTHING. */
#include "proc_pure_bitmap_decode_v1660.h"

#define SRC_V1660 020000UL
#define DST_V1660 030000UL
#define RAW_V1660 73UL
#define ENC_V1660 6UL
#define GUARD_V1660 0123456701234UL

extern void bitmap_encode_v1451(kword_t, kword_t, kword_t);
kword_t __test_exit;

static kword_t
value_v1660(kword_t i)
{
        if (i == 0UL || i == 35UL || i == 36UL)
                return 0777000UL + i;
        return 0UL;
}

static void
reset_v1660(void)
{
        kword_t i;
        kword_t *src = (kword_t *)(unsigned long)SRC_V1660;
        kword_t *dst = (kword_t *)(unsigned long)DST_V1660;
        for (i = 0UL; i < RAW_V1660; ++i) {
                src[i] = value_v1660(i);
                dst[i] = GUARD_V1660;
        }
        bitmap_encode_v1451(SRC_V1660, RAW_V1660, SRC_V1660 + 0200UL);
}

static int
check_v1660(int decoded)
{
        kword_t i;
        kword_t *dst = (kword_t *)(unsigned long)DST_V1660;
        for (i = 0UL; i < RAW_V1660; ++i)
                if (dst[i] != (decoded ? value_v1660(i) : GUARD_V1660))
                        return 0;
        return 1;
}

int
main(void)
{
        kword_t *packed = (kword_t *)(unsigned long)(SRC_V1660 + 0200UL);
        int rc;
        unsigned int kind;

        for (kind = 0U; kind < 8U; ++kind) {
                reset_v1660();
                if (kind == 1U)
                        packed[1] = 0UL; /* canonical literal absent */
                if (kind == 2U)
                        packed[5] |= 1UL; /* illegal last-mask pad */
                if (kind == 3U)
                        packed[0] |= 2UL; /* extra literal demanded */
                rc = proc_pure_bitmap_decode_v1660(
                    SRC_V1660 + 0200UL,
                    kind == 4U ? ENC_V1660 - 1UL :
                    (kind == 5U ? ENC_V1660 + 1UL : ENC_V1660),
                    kind == 6U ? SRC_V1660 + 0200UL : DST_V1660,
                    RAW_V1660);
                if (kind == 0U) {
                        if (rc != MM_OK || !check_v1660(1))
                                return 2;
                } else if (kind == 6U) {
                        if (rc != MM_ERR_INVAL ||
                            !check_v1660(0))
                                return 3;
                } else if (kind == 7U) {
                        if (rc != MM_OK || !check_v1660(1))
                                return 4;
                } else if (rc != MM_ERR_INVAL || !check_v1660(0)) {
                        return (int)(0100U + kind);
                }
        }
        return 0;
}
