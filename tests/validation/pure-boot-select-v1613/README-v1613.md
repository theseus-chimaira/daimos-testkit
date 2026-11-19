# v1613: genuine no-AUXSTORE versus disk-swap MINIT selection

`run-v1613.sh` extracts the actual
`proc_swap_minit_v481` source from DAIMOS
`system/kernel/modules/module_minit.c` into an isolated
C89 test translation unit. It supplies controlled
hardware-discovery and MRES-install results without
replacing the production selection branch itself.

It verifies:

* TSFS, opt-in PURE, no AUXST1 (`discover == -1`):
  select PURE and patch the original two scheduler hooks;
* TSFS, opt-in PURE, valid zero BACKSTORE descriptor:
  also select PURE;
* TSFS, positive validated BACKSTORE: install the
  existing disk MRES and all seven disk/backstore hooks;
* TSFS, opt-in OFF: no backing installs no SWAP/PURE;
* D6FS root: existing disk SWAP installation unchanged;
* an unsafe source mutation that restores the old
  `discover == -1` early return fails at an executed
  absent-AUXST1 assertion.

The test uses `cc -std=c89 -pedantic -Wall -Wextra -Werror`.
It does not prove physical simulator boot by itself;
that is separately tested by
`pure-boot-v1613/run-v1613.sh`.

Run:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/validation/pure-boot-select-v1613/run-v1613.sh
