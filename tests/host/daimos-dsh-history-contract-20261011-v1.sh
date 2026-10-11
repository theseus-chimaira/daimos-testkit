#!/bin/sh
# Bounded source-contract check; simulator persistence remains a separate gate.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
src=$DAIMOS_REPO/userland/dsh/dsh.c
[ -r "$src" ]
awk '
 /#define DSH_HISTORY_MAX 16U/ { slots=1 }
 /#define DSH_HISTORY_WORDS \(DSH_HISTORY_MAX \* \(DSH_LINE_MAX_WORDS \+ 1U\)\)/ { words=1 }
 /dsh_history_load\(\);/ { load=1 }
 /dsh_history_add\(\);/ { add=1 }
 /SYS_O_WRONLY \| SYS_O_CREAT \| SYS_O_APPEND/ { append=1 }
 /u_text_gets6\(&reader, rec,/ { native=1 }
 /write_rc = u_write_words_all\(fd, rec, count\)/ { full=1 }
 /close_rc = dsys_close\(fd\)/ { closed=1 }
 /write_rc != 0 \|\| close_rc != 0/ { warn=1 }
 /n != U_TEXT_EOF/ { tail=1 }
 /HISTFILE DAMAGED; VALID PREFIX LOADED/ { notice=1 }
 END { if (slots && words && load && add && append && native && full && closed && warn && tail && notice)
     print "DSH 512-word history contract PASS";
   else exit 1 }
' "$src"
grep -F 'dsh_history_path.len - 1U' "$src" >/dev/null
