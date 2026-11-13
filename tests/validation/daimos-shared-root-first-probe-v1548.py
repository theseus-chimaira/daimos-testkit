#!/usr/bin/env python3
"""Issue real root file reads from the independent F07 spinner PID5.

Only modify the disposable full-guest C source. Alternate root file
blocks so ordinary shared BCACHE hits do not conceal a physical read.
"""
from pathlib import Path
import sys


def inject(text):
    # v1348 adds a mandatory F07 high-pressure warmup inside the S branch.
    # Preserve that phase intact and replace only its final SLEEP loop.
    old = ("                        for (;;) {\n"
           "                                if (dsys_sleep(2U) != 0)\n"
           "                                        (void)dsys_exit(076);\n"
           "                        }\n"
           "                }\n"
           "#endif\n"
           "#if V1205_TEST_CONCURRENT\n")
    new = ("                        /* v1548: independent real FILE service.\n"
           "                         * A transfer may only HALT after an\n"
           "                         * active swapped owner has been allocated.\n"
           "                         * All probes use the published D6FS root.\n"
           "                         */\n"
           "                        for (;;) {\n"
           "                                int root_fd_v1548;\n"
           "                                unsigned int n_v1548;\n"
           "                                if (dsys_sleep(020U) != 0)\n"
           "                                        (void)dsys_exit(076);\n"
           "                                root_fd_v1548 =\n"
           "                                    dsys_open(v1075_path,SYS_O_RDONLY);\n"
           "                                if (root_fd_v1548 < 0)\n"
           "                                        (void)dsys_exit(075);\n"
           "                                for (n_v1548 = 0U;\n"
           "                                     n_v1548 < 020U; ++n_v1548) {\n"
           "                                        if (dsys_seek(root_fd_v1548,\n"
           "                                            (kword_t)(n_v1548 * 0200U),\n"
           "                                            SYS_SEEK_SET) ==\n"
           "                                            (kword_t)-1L)\n"
           "                                                break;\n"
           "                                        if (dsys_read_words(\n"
           "                                            root_fd_v1548,&word,1U) != 1)\n"
           "                                                break;\n"
           "                                }\n"
           "                                if (dsys_close(root_fd_v1548) != 0)\n"
           "                                        (void)dsys_exit(074);\n"
           "                        }\n"
           "                }\n"
           "#endif\n"
           "#if V1205_TEST_CONCURRENT\n")
    if text.count(old) != 1 or text.count("TEST_SIX6('S', ' ', ' ', ' ', ' ', ' ')") != 1:
        raise AssertionError("v1548 F07 spinner source anchor changed")
    return text.replace(old,new,1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: probe-v1548.py DISPOSABLE_F07_INIT_C")
    path=Path(sys.argv[1])
    path.write_text(inject(path.read_text()))
