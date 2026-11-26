# v1982 staged directory bitmap terminal and VM destruction

Run `make test-pure-bitmap-terminal-v1982 DAIMOS_REPO=/path/to/DAIMOS`.
The real v1979 DROP fixture creates each mode3 owner. Source-link
common proc_swap_detach, original RAW terminal, actual PREVM marker
instructions, real MM and PI, and the original/staged VM destroy entry.
Each CPU executes 65 operations through common detach with default
VM refusal, then 65 through the staged VM gate. Verify exact original
span across PREVM, exit status, both backing identities, mode and pins,
real free and reuse, lost/false replies, changed size/base, malformed
or foreign owners, pin counts 1..3, unmounted backing, corrupt payload,
invalid mode and live FILE refusal. No decoding needed for terminal.
Six source mutations must reach native assertions. The fixture does
not execute the entire scheduler, EXIT/WAIT or actual finalizer;
it extracts the original marker-preservation/rearm instructions.
No installed mode3 support.
