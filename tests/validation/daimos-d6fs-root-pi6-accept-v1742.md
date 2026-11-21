# D6FS ROOT DCT starvation regression accepted v1742

Date: 2026-11-21. DAIMOS commit `03dcb0e9`.

The previous 256K PDP-6 full-profile ROOT login reliably halted at
octal PC `004270` after a D6FS logical block `0743` read failed.
Type 270 CONI `001105004020` included DRL (`000020`). CPU PI trace
identified `CONO PI,0400` at PC `001604` in
`mm_alloc_aligned_noreclaim`; global interrupts remained disabled
for about 1360 simulated ticks while the DCT needed PI3 service.

The production fix inhibits only scheduler PI6 across the atomic
MM free-gap search and descriptor insertion, preserving the previous
PI6 enable state on return. PI3 and PI5 remain available for disk
transfers and completion. The instruction count is unchanged and
there is no new permanent or per-process data.

`daimos-k01-alloc-publish-pi-v1742.sh` passed on the native PDP-6.
It verifies atomic fit/insert, disk PI levels live during insertion,
correct nested PI restoration, typed allocation refusals, and AC16
preservation. Three unsafe mutants (PI6 left enabled, corrupted
saved register, global PI disabled) are rejected.

The fresh full 256K KCC guest
`daimos-dsh-full-profile-v1736.sh kcc 256` passed with DCS0 ROOT
login, DSH ECHO, external TRUE status 0, orderly HALT, and CLEAN
D6FS postflight. No image limit increase, disk retry workaround,
or fatal-root classification weakening was used.
The physical runner transcript SHA256 is
`b5addef58278179f07221499187ed4fe190fc1d57b44bd91fad8d5370a6c6244`.

This test does not establish the strict 32K KCORE RAM budget, all
possible MM critical sections, or a full post-change K03 physical
refusal rerun. Those are independent acceptance requirements.
