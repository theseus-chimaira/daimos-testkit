/* Host test harness: compile the unmodified KINIT discovery function from
 * auxstore_boot.c, extracted by the companion script. No device I/O occurs. */
#include <assert.h>
#include <stdio.h>

#define AUXSTORE_KIND_NONE 0U
#define AUXSTORE_KIND_DSK 1U
#define AUXSTORE_KIND_DRM 2U
#define MODULE_SERVICE_DRM_READ_BLOCK 1U
#define MODULE_SERVICE_DRM_WRITE_BLOCK 2U
#define MODULE_SERVICE_DSK_READ_SECTOR 3U
#define MODULE_SERVICE_DSK_WRITE_SECTOR 4U

typedef unsigned long kword_t;
unsigned int auxstore_kind, auxstore_unit;
kword_t auxstore_backstore_blocks, auxstore_logstore_blocks;
kword_t auxstore_cache_blocks;
static unsigned int drum_present, disk_present;
static kword_t drum_swap, disk_swap;
static unsigned int drum_reads, disk_reads;

static unsigned int
module_service_get(unsigned int service)
{
        return service <= 2U ? drum_present : disk_present;
}

static int
auxstore_try(unsigned int kind, unsigned int unit)
{
        kword_t blocks;

        assert(unit == 0U);
        if (kind == AUXSTORE_KIND_DRM) {
                ++drum_reads;
                if (!drum_present) return -1;
                blocks = drum_swap;
        } else {
                ++disk_reads;
                if (!disk_present) return -1;
                blocks = disk_swap;
        }
        auxstore_kind = kind;
        auxstore_unit = unit;
        auxstore_backstore_blocks = blocks;
        return 0;
}

#include "auxstore-discovery-under-test.c"

static void
check(unsigned int drum, unsigned int disk, kword_t ds, kword_t ks,
    unsigned int expected)
{
        drum_present = drum;
        disk_present = disk;
        drum_swap = ds;
        disk_swap = ks;
        drum_reads = disk_reads = 0U;
        assert(auxstore_boot_discover() == (expected ? 0 : -1));
        if (expected) assert(auxstore_kind == expected);
}

int main(void)
{
        check(0, 0, 0, 0, AUXSTORE_KIND_NONE);
        check(1, 0, 128, 0, AUXSTORE_KIND_DRM);
        check(0, 1, 0, 128, AUXSTORE_KIND_DSK);
        check(1, 1, 128, 128, AUXSTORE_KIND_DRM);
        check(1, 1, 0, 128, AUXSTORE_KIND_DSK);
        check(1, 1, 0, 0, AUXSTORE_KIND_DRM);
        check(1, 0, 0, 0, AUXSTORE_KIND_DRM);
        puts("daimos-auxstore-choice-v492: PASS");
        return 0;
}
