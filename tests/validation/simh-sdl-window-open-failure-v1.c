/* Regression for the Type 340 display's failed SDL window open.
 * This harness deliberately returns an error from vid_open().  A failure
 * must not be followed by vid_map_rgb(), which requires a live pixel format.
 */
#include <stdio.h>

#include "sim_defs.h"
#include "sim_video.h"
#include "display/ws.h"

/* The test harness uses libc stderr, not the SIMH SCP formatter. */
#ifdef fprintf
#undef fprintf
#endif

static int mapped_after_failure;

t_stat
vid_open(DEVICE *dev, const char *name, uint32 width, uint32 height,
    int flags)
{
    (void)dev;
    (void)name;
    (void)width;
    (void)height;
    (void)flags;
    return SCPE_OPENERR;
}

uint32
vid_map_rgb(uint8 r, uint8 g, uint8 b)
{
    (void)r;
    (void)g;
    (void)b;
    ++mapped_after_failure;
    return 0;
}

t_stat
vid_set_cursor(t_bool visible, uint32 width, uint32 height, uint8 *data,
    uint8 *mask, uint32 hot_x, uint32 hot_y)
{
    (void)visible;
    (void)width;
    (void)height;
    (void)data;
    (void)mask;
    (void)hot_x;
    (void)hot_y;
    return SCPE_OK;
}

int
main(void)
{
    int rc;

    ws_headless = 0;
    rc = ws_init("failure test", 64, 64, 2, NULL);
    if (rc != 0 || mapped_after_failure != 0) {
        fprintf(stderr,
            "failed open: ws_init=%d, unexpected color mappings=%d\n",
            rc, mapped_after_failure);
        return 1;
    }
    return 0;
}
