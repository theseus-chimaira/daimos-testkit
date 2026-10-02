#include "module_runtime.h"
#include "kcore_pi.h"

extern kword_t native_sys_putchar_call;
extern kword_t drm236_read_jump;
extern kword_t drm236_write_jump;
extern void daimos_module_runtime_init_lh(kword_t *word, unsigned int address);

kword_t daimos_module_runtime_pdp6_result;
kword_t pdp10_pi_handlers[PDP10_PI_HANDLER_CAPACITY];
static kword_t old_image[011];
static kword_t new_image[011];

int
daimos_module_runtime_pdp6_test(void)
{
        unsigned int old_base;
        unsigned int new_base;
        unsigned int i;

        old_base = (unsigned int)(unsigned long)old_image;
        new_base = (unsigned int)(unsigned long)new_image;
        for (i = 0U; i < 011U; ++i) {
                old_image[i] = 0UL;
                new_image[i] = 0UL;
        }
        for (i = 0U; i < PDP10_PI_HANDLER_CAPACITY; ++i)
                pdp10_pi_handlers[i] = 0UL;
        for (i = 0U; i < MODULE_DYNAMIC_BIND_MAX; ++i)
                module_dynamic_bindings[i] = 0UL;

        /* Three initialized words, eight image words, one relocation-map word. */
        old_image[0] = 0200000000000UL | (kword_t)(old_base + 2U);
        old_image[1] = 012345UL;
        daimos_module_runtime_init_lh(&old_image[1], old_base + 3U);
        /* Deliberately absent from the relocation map: dynamic binding fixes it. */
        old_image[2] = 0254000000000UL | (kword_t)(old_base + 6U);
        old_image[010] = (1UL << 34U) | (2UL << 32U);

        module_runtime_descs[1] = (03UL << 18U) | (kword_t)old_base;
        module_dynamic_bindings[0] = (1UL << 18U) | 2UL;
        native_sys_putchar_call = 0254000000000UL | (kword_t)(old_base + 4U);
        pdp10_pi_handlers[0] = (kword_t)(old_base + 5U);
        drm236_read_jump = 0254000000000UL | (kword_t)(old_base + 6U);
        drm236_write_jump = 0254000000000UL | (kword_t)(old_base + 7U);

        if (module_runtime_move(1U, new_base, 011U) != 0)
                return 1;
        if (MODULE_RUNTIME_BASE(module_runtime_descs[1]) != new_base)
                return 2;
        if ((new_image[0] & MODULE_HALF_MASK) != (kword_t)(new_base + 2U))
                return 3;
        if (((new_image[1] >> 18U) & MODULE_HALF_MASK) !=
            (kword_t)(new_base + 3U))
                return 4;
        if ((new_image[2] & MODULE_HALF_MASK) != (kword_t)(new_base + 6U))
                return 5;
        if ((native_sys_putchar_call & MODULE_HALF_MASK) !=
            (kword_t)(new_base + 4U))
                return 6;
        if ((pdp10_pi_handlers[0] & MODULE_HALF_MASK) !=
            (kword_t)(new_base + 5U))
                return 7;
        if ((drm236_read_jump & MODULE_HALF_MASK) !=
            (kword_t)(new_base + 6U))
                return 8;
        if ((drm236_write_jump & MODULE_HALF_MASK) !=
            (kword_t)(new_base + 7U))
                return 9;
        return 0;
}
