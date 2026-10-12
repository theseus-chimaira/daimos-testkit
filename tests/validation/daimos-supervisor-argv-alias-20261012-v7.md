# SUPERVISOR v7: retain INIT handoff pathnames without a BSS copy

The EXEC handoff copies each validated counted SIXBIT pathname into
the SUPERVISOR startup argv area. The kernel starts the process with
SP above the stored record data. SUPERVISOR v7 keeps a pointer to
each original path, instead of storing eighteen additional BSS words
per service. This preserves the eight-entry service limit, full path
lengths and RESPawn pathname lifetime. The path pointer is a logical
user VM address, valid following physical VM relocation.

PDP-6 measured sizes, octal words:

| | v6 | v7 |
| --- | ---: | ---: |
| SUPERVISOR image | 001236 | **001210** |
| BSS | 000261 | **000051** |
| Text+BSS+origin | 001537 | **001301** |
| VM (02000 default stack) | 004000 | **004000** |

Standard PDP-6 image build and 115/115 DSH conformance: PASS.
The v7 size guard validates executable text and rounded VM. A separate
maximum-eight-services with full-length paths, restart/error stress
test is still required; the DSH conformance suite is not that test.

A single 02000-octal-word process would leave 000677 words for both
startup argument records and later stack use, and therefore needs an
explicit stack-layout and high-water analysis. No stack ABI change was
made in v7.
