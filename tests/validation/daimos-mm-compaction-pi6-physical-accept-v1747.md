# K01 PI6-safe physical compaction acceptance v1747

Date: 2026-11-21. Source: DAIMOS
`cbcd7a7e663441f2652f440c7629d6a108a580a5`, containing the
`d475fcd3` MM relocation and PI5 wakeup corrections. Native compiler:
KCC source `551f406`; installed compiler SHA256 begins `fbe85b127e2004fa`.

`daimos-mm-compaction-scheduler-v1747.sh` is the KCC-native variant of
the historical GCC v561 compaction workload. The C guest and its
child-data/BRK integrity oracle are unchanged. It compiles the custom
INIT program through the installed KCC PDP-6 assembler path and builds
a fresh 256K full-profile PDP-6 guest with that exact INIT image.

Physical run: **PASS**. SIMH hit the production `mm_compact` breakpoint
twice (octal `002030`) and the production `vm_extent_move` breakpoint
twice (octal `023416`), then the guest completed its `300000]CQ`
child-data integrity marker and HALTed normally. The expected source
test requires the complete AB/child-data/CQ sequence; a mere HALT is
insufficient.

Evidence SHA256:

- Simulator transcript:
  `61639f2943af8f1fc38a2675b19b5bbaf282237cfa732f96eac2b42c5f142354`
- Physical-run driver transcript:
  `12f4bc16f1a3c20f25b0b64037542c9faefcf0f91a9616ea3cd1f2b493e88a2d`
- Compiled custom INIT DXR:
  `f544362e6d5584d72cf491036b0a970e72fcd8ed21e6ee0a701c14000e1e1c48`

The separate K01 source-linked suite passed 34/34 cases, including
`daimos-k01-vm-sleep-wake-v1745` (inject PI5 disk completion during
physical copy) and `daimos-k01-relocate-pin-race-v1745` (four unsafe
mutants rejected). Native acceptance is independent of this physical
test. The full 256K KCC ROOT/DSH/HALT/CLEAN guest also passed.

Historical GCC `daimos-mm-compaction-scheduler-v561.sh` halted at PC
`000000` after device initialization and before any compaction
breakpoint in the current checkout. Its failure was not reclassified
as a pass or attributed to the MM fix without a control run.

The v1747 result does not establish the strict 32K KCORE address
budget, permanent-provider recovery (K04), or all possible scheduler
interrupt interleavings. It does physically exercise actual MM/VM
relocation and guest data integrity with disk PI service retained.
