# DSH SIMH prompt recognition regression — 2026-10-11 v1

`daimos-simh-harness-v6.sh` previously accepted the substring `# ` anywhere
in newly received terminal bytes as completion of a DSH command. The input
echo from `ECHO COMMENTOK # IGNORED` therefore satisfied the prompt wait
prematurely and the harness submitted following commands while DSH was still
processing the preceding line. This made nine later quotation/globbing/control
probes fail with truncated/mixed commands; the shell itself was correct.

The harness now requires the DSH `# ` prompt at the start of a logical
terminal line (carriage returns are normalized). Other markers remain
unchanged. The original 115-probe full conformance suite was rerun against
an isolated PDP-6 DSH image after bounded `$()` and interactive foreground
TTY fixes: **115/115 PASS**. The same suite previously returned 106/115 with
the unanchored marker detector. The image used the user-approved temporary
`DSH_IMAGE_LIMIT=037000` build override; its default remains `036000`.

Separate targeted tests also cover `$()` success/error/overflow, and a
nine-probe worker-session path covering background groups, pipelines,
foreground control and orderly HALT. HISTFILE corruption injection remains a
separate acceptance requirement.
