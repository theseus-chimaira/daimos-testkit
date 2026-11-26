# KCC qualified static absolute word pointers v59g

`sh run-v59g.sh` runs the source on native PDP-6 under both -O and -O0.
The old installed compiler 6423263 emits unsupported .LINK constructors
for the qualified non-null pointers and fails before assembly. KCC
89c036e emits direct word data; native loads, stores, numeric pointer
identity and null pointer are checked. Candidate KCC can be selected
with the KCC environment variable. No startup or DAS workaround.
