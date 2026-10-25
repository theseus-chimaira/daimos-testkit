#!/bin/sh
# Snapshot the 256K PDP-6 kernel immediately before each swap-out and
# after it commits its process-extent release (at storage publication).
# Uses an existing isolated boot image: no recompilation or guest changes.
set -eu
: "${DAIMOS_MM_SNAPSHOT_BOOT:?point to retained boot/pdp6 directory}"
: "${TMPDIR:?}"
boot=$DAIMOS_MM_SNAPSHOT_BOOT
out=$TMPDIR/daimos-mm-swap-snapshot-v295-$$.log
ini=$boot/boot.snapshot-v295.ini
[ -f "$boot/boot.headless.ini" ] && [ -f "$boot/kcore.map" ] || exit 2
before=$(awk '$1=="proc_swap_out" {print $2}' "$boot/kcore.map")
after=$(awk '$1=="proc_storage_publish_v30" {print $2}' "$boot/kcore.map")
sed '/^go 020$/,$d' "$boot/boot.headless.ini" > "$ini"
for pc in "$before" "$after"; do
  printf 'break %s;examine 17;examine 24722;examine 24772;examine 25024-25146;examine 40350-40520;examine 40750-41145;go\n' "$pc" >> "$ini"
done
# Inspect after the simulator stops at unexpected UUO, too.
printf 'go 020\nexamine 17\nexamine 25024-25146\nexamine 40350-40520\nexamine 40750-41145\nexit\n' >> "$ini"
(cd "$boot" && TERM=dumb timeout -k 2s 300s stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$ini") > "$out" 2>&1 || true
printf 'snapshot log: %s\n' "$out"
grep -E 'Breakpoint, PC:|UUO |HALT instruction' "$out" | tail -30 || true
