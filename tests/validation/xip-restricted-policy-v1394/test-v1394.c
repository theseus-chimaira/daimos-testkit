/* Exact trusted no-write XIP program: neither a general DXR nor PURE claim
 * alone authorizes code fetch from shared writable physical RAM.
 */
#include "proc_xip_policy_v1394.h"

#define XIP_WORDS 04000UL
#define XIP_ENTRY 020UL
#define MOVEI_2(op) (((kword_t)0201UL << 27U) | \
                     ((kword_t)2UL << 23U) | (op))

static kword_t image[XIP_WORDS];
kword_t __test_exit;

int
main(void)
{
        kword_t saved;

        image[0] = 054506000000UL;
        image[1] = (0200000UL << 18U) | XIP_ENTRY;
        image[XIP_ENTRY] = MOVEI_2(01234UL);
        image[XIP_ENTRY + 1UL] = 040000000000UL;
        if (proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 1U, 0U, 0U) != 0)
                return 1;

        if (proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            1U, 1U, 0U, 0U) == 0 ||
            proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 0U, 0U, 0U) == 0 ||
            proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 1U, 1U, 0U) == 0 ||
            proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 1U, 0U, 1U) == 0 ||
            proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY + 1UL,
            0U, 1U, 0U, 0U) == 0 ||
            proc_xip_policy_v1394(image, XIP_WORDS - 1UL, XIP_ENTRY,
            0U, 1U, 0U, 0U) == 0 ||
            proc_xip_policy_v1394(image, 02000UL, XIP_ENTRY,
            0U, 1U, 0U, 0U) == 0 ||
            proc_xip_policy_v1394((const kword_t *)0, XIP_WORDS,
            XIP_ENTRY, 0U, 1U, 0U, 0U) == 0)
                return 2;

        saved = image[0];
        image[0] = 0UL;
        if (proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 1U, 0U, 0U) == 0)
                return 3;
        image[0] = saved;

        saved = image[1];
        image[1] = XIP_ENTRY;          /* PURE flag missing */
        if (proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 1U, 0U, 0U) == 0)
                return 4;
        image[1] = saved;

        saved = image[XIP_ENTRY];
        image[XIP_ENTRY] = 0202002001234UL; /* self-modifying MOVEM */
        if (proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 1U, 0U, 0U) == 0)
                return 5;
        image[XIP_ENTRY] = saved;

        image[XIP_ENTRY] |= ((kword_t)1UL << 22U); /* indirect MOVEI */
        if (proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 1U, 0U, 0U) == 0)
                return 6;
        image[XIP_ENTRY] = saved;

        image[XIP_ENTRY + 1UL] = 040000000000UL | 1UL;
        if (proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 1U, 0U, 0U) == 0)
                return 7;
        image[XIP_ENTRY + 1UL] = 040000000000UL;

        image[017UL] = 1UL;
        if (proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 1U, 0U, 0U) == 0)
                return 8;
        image[017UL] = 0UL;
        image[XIP_WORDS - 1UL] = 1UL;
        if (proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 1U, 0U, 0U) == 0)
                return 9;
        image[XIP_WORDS - 1UL] = 0UL;

        return proc_xip_policy_v1394(image, XIP_WORDS, XIP_ENTRY,
            0U, 1U, 0U, 0U) != 0 ? 10 : 0;
}
