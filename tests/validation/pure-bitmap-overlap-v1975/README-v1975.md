# K11 staged forward overlap validation v1975

Run `DAIMOS_REPO=$HOME/git/DAIMOS sh run-v1975.sh` with installed
PDP10 tools, or use `KCC=/path/to/kcc` for a candidate compiler.
The real DAIMOS v1451 assembler and v1975 bounded wrappers are linked
on native PDP-6, without an MM/scheduler stub pretending to own RAM.
The test uses fixed private test addresses and compares the entire
256-word arena to its original contents plus the exact output region.

Lengths 1, 2, 35, 36, 37, 72 and 73, six word distributions and nine
relative offsets yield 378 encode requests and 234 decode requests.
The exact-size planner is also invoked read-only for every encode.
269 successful encodes/decodes, 199 unsafe-overlap refusals, and 144
nonshrinking encoding refusals. Additional focused tests cover short
capacity, identical bases, safe shifted overlap, illegal mask padding,
zero literals, truncation and extra input. The output count must not
change on refusal. Mutating each unread-input check separately must
execute and fail at the full-arena comparison (exit 2 and 5).

This is a forward codec component test, not an installed mode3 owner,
reverse codec, exclusive MM scratch lease, or physical process test.
