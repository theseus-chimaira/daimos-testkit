#include "vfs.h"

int __test_exit;
extern kword_t proc_current_ptr;
extern void vm_user_mapping_hold(void);
extern void vm_user_mapping_release(void);
static kword_t process_record[4];
static kword_t user_area[040];

int main(void)
{
        const kword_t original = (((kword_t)0123456U) << 18) | 0700U;
        process_record[0] = ((kword_t)(unsigned long)user_area) << 18;
        proc_current_ptr = (kword_t)(unsigned long)process_record;
        user_area[024] = original;

        vm_user_mapping_hold();
        if (user_area[024] != (original | 02U)) return 1;
        vm_user_mapping_release();
        if (user_area[024] != original) return 2;

        /* The user control-word state must survive an already-set hold. */
        user_area[024] = original | 02U;
        vm_user_mapping_hold();
        if (user_area[024] != (original | 02U)) return 3;
        vm_user_mapping_release();
        if (user_area[024] != original) return 4;

        /* Kernel boot/no-current-u-area path must return safely. */
        process_record[0] = 0;
        vm_user_mapping_hold();
        vm_user_mapping_release();
        return 0;
}
