# P1-E v1612: measured PDP-6 PURE MRES optimization

The source-linked test runs the actual v1612 retry policy and
the unchanged v1381 DROP, v1384 prefix and v1391 bounded FULL
transactions under the PDP-6 simulator:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/validation/pure-service-v1612/run-v1612.sh

Additional negative cases include a duplicate MM process owner
and a pinned PACKED suffix. Neither may clear TRANSITION or
publish READY_ONCE. The private unsafe-READY source mutation
must still be rejected by the executed guest.

The KCC source/package toggle test checks default OFF,
experimental ON and default OFF again in the *same* build
directory. It requires a generated zero-cost fold plan, an
installed v1612 PURE MRES of 2196 words and unchanged KCORE:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/validation/pure-service-v1612/boot-mode-v1612.sh

The separate GCC low-memory footprint test checks the opt-in
MRES at 1758 installed words and the fixed KCORE low-end
symbol at 024254 octal:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/validation/pure-service-v1612/lowmem-size-v1612.sh

The historical v1611 source-linked service suite remains
available independently, and its policy source is unchanged.
Only the optional v1612 module receives the one-pass MM
owner check and link-time folding.

These are compiled/native and link-budget checks, not a
complete booted physical no-AUXST1 acceptance. Normal KINIT
remains DAIMOS_PURE_MRES_ENABLED=0.
