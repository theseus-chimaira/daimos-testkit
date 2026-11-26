# v1953 Type-270 address-acquisition media loss

DEC H-270 (Apr 1966), Fig.3-1, pp.3-25/26: OPR loss
sets FER; an ADT address error sets ADE and FER. The internal
SNA-to-ADT ATP delay is not an external disk-sector pulse.
An operator SIMH DETACH is a modeled media disappearance,
not a claim about exact mechanical timing of real hardware.

Native independent tests halt at original linked instruction
boundaries after DATAO or observed ADT. Real DETACH DSK0,
no guest status or controller-state deposits. The three cases
SNA, ADT, and immediate reattach during SNA fail on cb6a255:
SNA stays stuck (CONI200001; after reattach200000), ADT reports
OPR without FER/ADE (100001), immediate reattach SNA200000.
Unselected DSK1 detach is a passing control.

Simulator 12dcd35 preserves SNA's pending ATP, latches FER
immediately and terminates the abandoned acquisition with
ADE/FER in ADT, even if DSK0 was reattached before ATP.
An ADT detach cancels the seek and sets ADE/FER without false
DFR or fabricated IDS. New legal DATAO after SCL recovers.
Four native cases and all three v1950 native probes pass on
the candidate source; media unchanged. This patch deliberately
does not alter busy (ALS/CMS/SCS/SCE) or DFR detach semantics.

The physical KCC FULL boot-loss script binds the original
installed DSK MRES through dsk270_read_call at d6fs_boot_select,
checks actual DATAO/CONO/error opcodes, and removes DSK0
immediately after the native DATAO to address 0 at 034127.
Real PI5 error handler is reached with CONI000125200003
(SNA, FER, OPR, EFE enabled). Root selector explicit DSK;
original four-member D6FS cannot mount with member 0 absent.
Exact KINIT HALT101271, namespace root0, no INIT, unchanged
private disk copies. No kernel instrumentation or state writes.
Three current FULL root selection cases (disk, AUTO tape-dsk,
explicit tape-dsk) pass on unchanged KCC images and candidate.
No claim of active sector/transfer recovery or active disk-swap
lifecycle acceptance.

Evidence: $TMPDIR/k09-dsk-loss-v1953.iSRMsJ.
Candidate SHA256 3f056a960aeb74f0e575b2089e967381bfbe9a92193f8030dec9f1d310bf8484.
Original, original-extended, candidate, octoflop-candidate,
boot-loss and root-regression. Source committed as 12dcd35.
