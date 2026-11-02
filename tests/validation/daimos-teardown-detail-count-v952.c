/* v952: FILE count must not contain bits from the first-FD field. */
#include "syscall.h"

int main(void)
{
        unsigned int value;
        unsigned int count;
        unsigned int fd;
        unsigned int err;

        for (count = 0U; count <= 020U; count++) {
                for (fd = 0U; fd <= 020U; fd++) {
                        for (err = 0U; err <= 6U; err++) {
                                value = 1U | (count << 2U) |
                                    (fd << 8U) | (err << 15U);
                                if (SYS_TEARDOWN_STAGE(value) != 1U ||
                                    SYS_TEARDOWN_DETAIL_VALUE(value) != count ||
                                    SYS_TEARDOWN_DETAIL_FD(value) != fd ||
                                    SYS_TEARDOWN_DETAIL_FILE_ERROR(value) != err)
                                        return 1;
                        }
                }
        }
        /* v951 real D6FS observed diagnostic, octal 0101405. */
        value = 0101405U;
        if (SYS_TEARDOWN_DETAIL_VALUE(value) != 1U ||
            SYS_TEARDOWN_DETAIL_FD(value) != 3U ||
            SYS_TEARDOWN_DETAIL_FILE_ERROR(value) != 1U)
                return 2;
        return 0;
}
