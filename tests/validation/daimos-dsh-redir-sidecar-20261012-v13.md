# DSH optional redirection records: PDP-6 verification (v13)

The DSH AST node no longer reserves two seven-word SIXBIT redirection
records in every descriptor. Redirections instead occupy fourteen words
in the existing optional per-node payload. Stored functions retain
independent copied payloads and rebind pointers after compaction.

Source: DAIMOS `dsh-redir-sidecar-20261012-v13`.

Acceptance with fresh independently built PDP-6 disk images:

- Production image build: PASS, image 035726 octal words (under 036000).
- Static BSS: 003374 octal words, versus 004034 at v10.
- DSH full conformance through SIMH CTY: **115/115 PASS**.
- `probes/daimos-dsh-redir-sidecar-20261012-v13.txt`:
  **7/7 PASS** (output, append, readback, stored function input redirection,
  function reuse, output redirection after redefinition, cleanup).

The change saves 288 decimal static BSS words for 27 additional image
words. Its initial aligned process allocation remains 044000 octal words;
this test does **not** establish 32K PDP-6 bootability. A prior attempt
to run the long HELP DAS probe through DCS0 lost characters; rerunning
through CTY passed all 115 probes. Do not classify DCS0 character loss
as a DSH AST regression.
