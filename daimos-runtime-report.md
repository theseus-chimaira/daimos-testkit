# DAIMOS SIMH runtime report

## Summary

- Total probes: 115
- PASS: 115
- FAIL: 0

## Results

| Outcome | Probe | Command | Error |
|---|---|---|---|
| PASS | dsh-comment-in-word | `ECHO A#B` |  |
| PASS | dsh-empty-argument | `ECHO A "" B` |  |
| PASS | dsh-quoted-keyword | `ECHO "IF"` |  |
| PASS | dsh-single-quote-backslash | `ECHO 'A\B'` |  |
| PASS | dsh-case-wildcard | `CASE FOO IN WHEN B* DO ECHO BAD WHEN F?O DO ECHO CASEOK ESAC` |  |
| PASS | dsh-case-quoted-wildcard | `CASE FOO IN WHEN "F?O" DO ECHO BAD WHEN F* DO ECHO CASEQUOTEOK ESAC` |  |
| PASS | dsh-glob-create | `ECHO /SYSTEM/DSHG*` |  |
| PASS | dsh-glob-quoted | `ECHO "/SYSTEM/DSHG*"` |  |
| PASS | dsh-glob-unmatched | `ECHO /SYSTEM/NOMATCH*` |  |
| PASS | dsh-glob-variable-unquoted | `ECHO $P` |  |
| PASS | dsh-glob-variable-quoted | `ECHO "$P"` |  |
| PASS | dsh-glob-cleanup-one | `RM /SYSTEM/DSHG1` |  |
| PASS | dsh-glob-cleanup-two | `RM /SYSTEM/DSHG2` |  |
| PASS | dsh-variable-basic | `SET DSHV VALUE; ECHO $DSHV` |  |
| PASS | dsh-variable-bracketed | `SET DSHV VALUE; ECHO $[DSHV]X` |  |
| PASS | dsh-variable-over-sixteen | `ECHO $V01:$V16:$V20` |  |
| PASS | dsh-variable-resize-unset | `ECHO $KEEP; ECHO $GROW; ECHO $AFTER; ECHO X$V10` |  |
| PASS | dsh-status-failure | `FALSE; ECHO $?` |  |
| PASS | dsh-status-success | `TRUE; ECHO $?` |  |
| PASS | help-compact-echo | `HELP ECHO` |  |
| PASS | help-compact-das | `HELP DAS` |  |
| PASS | man-long-das | `MAN DAS` |  |
| PASS | apropos-summary-das | `APROPOS ASSEMBLER` |  |
| PASS | help-not-available | `HELP NOSUCHHELP` |  |
| PASS | manual-not-available | `MAN NOSUCHHELP` |  |
| PASS | dsh-status-not-found-127 | `NOSUCHCOMMAND; ECHO STATUS:$?` |  |
| PASS | dsh-status-not-executable-create | `ECHO NOTEXEC > /CONFIG/DSHNOEXEC` |  |
| PASS | dsh-status-not-executable-126 | `/CONFIG/DSHNOEXEC; ECHO STATUS:$?` |  |
| PASS | dsh-status-not-executable-cleanup | `RM /CONFIG/DSHNOEXEC` |  |
| PASS | dsh-status-pipeline-builtin-126 | `CD / ! CAT; ECHO STATUS:$?` |  |
| PASS | dsh-redir-create | `ECHO REDIR1 > /CONFIG/DSHREDIR` |  |
| PASS | dsh-redir-append | `ECHO REDIR2 >> /CONFIG/DSHREDIR` |  |
| PASS | dsh-redir-input | `CAT < /CONFIG/DSHREDIR` |  |
| PASS | dsh-redir-failure-status | `ECHO BAD > /NO/SUCH/PATH; ECHO STATUS:$?` |  |
| PASS | dsh-pipeline-data | `ECHO PIPEOK ! CAT` |  |
| PASS | dsh-pipeline-last-failure | `TRUE ! FALSE; ECHO STATUS:$?` |  |
| PASS | dsh-pipeline-last-success | `FALSE ! TRUE; ECHO STATUS:$?` |  |
| PASS | dsh-pipeline-three-stage | `ECHO THREE ! CAT ! CAT` |  |
| PASS | dsh-pipeline-eight-stage | `ECHO P8 ! CAT ! CAT ! CAT ! CAT ! CAT ! CAT ! CAT` |  |
| PASS | dsh-pipeline-partial-launch-failure | `ECHO PARTIAL ! NOSUCHCOMMAND ! CAT; ECHO STATUS:$?` |  |
| PASS | dsh-export-child | `EXPORT DSHX=CHILD; DSH -C 'ECHO $DSHX'` |  |
| PASS | dsh-c-positional | `DSH -C 'ECHO C:$0:$1:$2:$#' ONE TWO` |  |
| PASS | dsh-positional-three-eight | `ECHO 'A B C D E F G H' ! XARGS -N 10 DSH /CONFIG/DSHP8` |  |
| PASS | dsh-positional-three-eight-cleanup | `RM /CONFIG/DSHP8` |  |
| PASS | dsh-positional-at | `DSH -C 'ECHO AT:$@' ONE TWO THREE` |  |
| PASS | dsh-positional-at-quoted | `DSH -C 'ECHO AT:"$@"' ONE TWO THREE` |  |
| PASS | dsh-positional-missing-nine | `DSH -C 'ECHO NINE:X$9Y' ONE` |  |
| PASS | dsh-shell-pid | `DSH -C 'ECHO PID:$$'` |  |
| PASS | dsh-adjacent-fragments | `ECHO A'B'"C"D` |  |
| PASS | dsh-quoted-variable-one-word | `SET V 'A B'; ECHO X"$[V]"Y` |  |
| PASS | dsh-begin-status | `BEGIN TRUE; FALSE END; ECHO STATUS:$?` |  |
| PASS | dsh-paren-status | `( TRUE; FALSE ); ECHO STATUS:$?` |  |
| PASS | dsh-begin-state | `BEGIN SET GV BEGINOK END; ECHO $GV` |  |
| PASS | dsh-paren-state | `( SET PV PARENOK ); ECHO $PV` |  |
| PASS | dsh-script-create | `ECHO 'ECHO SCRIPT:$0:$1:$#' > /CONFIG/DSHTEST` |  |
| PASS | dsh-script-readable | `CAT /CONFIG/DSHTEST` |  |
| PASS | dsh-script-positional | `DSH /CONFIG/DSHTEST ARG` |  |
| PASS | dsh-stdin-script-create | `ECHO 'ECHO STDINOK' > /CONFIG/DSHSTDIN` |  |
| PASS | dsh-stdin-script-native-text | `DSH < /CONFIG/DSHSTDIN` |  |
| PASS | dsh-source-create | `ECHO 'ECHO SOURCE:$1' > /CONFIG/S` |  |
| PASS | dsh-source-main-create | `ECHO 'SOURCE /CONFIG/S I;ECHO OUTER:$1' > /CONFIG/M` |  |
| PASS | dsh-source-positional-restore | `DSH /CONFIG/M O` |  |
| PASS | dsh-profile-input-create | `TOUCH /CONFIG/DSHEMPTY` |  |
| PASS | dsh-system-profile-create | `ECHO 'SET ORDER SYSTEM' > /CONFIG/DSH.PROFILE` |  |
| PASS | dsh-home-profile-create | `ECHO 'ECHO ORDER:$ORDER' > /CONFIG/.DSH.PROFILE` |  |
| PASS | dsh-login-profile-order | `EXPORT HOME=/CONFIG; DSH -L < /CONFIG/DSHEMPTY` |  |
| PASS | dsh-nonlogin-no-profile | `EXPORT HOME=/CONFIG; DSH < /CONFIG/DSHEMPTY` |  |
| PASS | dsh-system-profile-bad-create | `ECHO 'IF' > /CONFIG/DSH.PROFILE` |  |
| PASS | dsh-login-profile-error-status | `EXPORT HOME=/CONFIG; DSH -L < /CONFIG/DSHEMPTY; ECHO STATUS:$?` |  |
| PASS | dsh-system-profile-remove | `RM /CONFIG/DSH.PROFILE` |  |
| PASS | dsh-home-profile-remove | `RM /CONFIG/.DSH.PROFILE` |  |
| PASS | dsh-login-profile-missing-ok | `EXPORT HOME=/CONFIG; DSH -L < /CONFIG/DSHEMPTY; ECHO STATUS:$?` |  |
| PASS | dsh-function-argument-return | `DEF F DO ECHO FUNC:$1; RETURN 7 DONE; F ARG; ECHO STATUS:$?` |  |
| PASS | dsh-function-redefine | `DEF F DO ECHO OLD DONE; DEF F DO ECHO NEW DONE; F` |  |
| PASS | dsh-function-recursion-limit | `DEF F DO F DONE; F; ECHO STATUS:$?` |  |
| PASS | dsh-function-table-limit | `DEF A DO TRUE DONE; DEF B DO TRUE DONE; DEF C DO TRUE DONE; DEF D DO TRUE DONE; ECHO STATUS:$?` |  |
| PASS | dsh-if-then | `IF TRUE THEN ECHO IFOK ELSE ECHO BAD FI` |  |
| PASS | dsh-if-else | `IF FALSE THEN ECHO BAD ELSE ECHO ELSEOK FI` |  |
| PASS | dsh-for | `FOR I IN A B C DO ECHO F:$I DONE` |  |
| PASS | dsh-while-return | `DEF F DO WHILE TRUE DO ECHO WHILEOK; RETURN 0 DONE DONE; F` |  |
| PASS | dsh-until-return | `DEF F DO UNTIL FALSE DO ECHO UNTILOK; RETURN 0 DONE DONE; F` |  |
| PASS | dsh-not | `NOT FALSE; ECHO $?` |  |
| PASS | dsh-and | `TRUE AND ECHO ANDOK` |  |
| PASS | dsh-or | `FALSE OR ECHO OROK` |  |
| PASS | dsh-script-cleanup | `RM /CONFIG/DSHTEST` |  |
| PASS | dsh-stdin-script-cleanup | `RM /CONFIG/DSHSTDIN` |  |
| PASS | dsh-redir-cleanup | `RM /CONFIG/DSHREDIR` |  |
| PASS | dsh-source-cleanup | `RM /CONFIG/S` |  |
| PASS | dsh-source-main-cleanup | `RM /CONFIG/M` |  |
| PASS | dsh-profile-input-cleanup | `RM /CONFIG/DSHEMPTY` |  |
| PASS | dsh-background-group-state | `SET BGVAR PARENT; BEGIN SET BGVAR CHILD; ECHO BG:$BGVAR END &; WAIT %1; ECHO PARENT:$BGVAR` |  |
| PASS | dsh-background-group-andor-status | `BEGIN FALSE OR ECHO BGOR; TRUE AND ECHO BGAND; FALSE END &; WAIT %1; ECHO STATUS:$?` |  |
| PASS | dsh-job-done-background-number | `FALSE &` |  |
| PASS | dsh-job-done-listing | `JOBS` |  |
| PASS | dsh-job-done-reclaimed | `JOBS` |  |
| PASS | dsh-job-background-number | `CAT &` |  |
| PASS | dsh-job-stopped-listing | `JOBS` |  |
| PASS | dsh-job-wait-stopped | `WAIT %1; ECHO WAITSTATUS:$?` |  |
| PASS | dsh-job-stopped-survives-wait | `JOBS` |  |
| PASS | dsh-job-default-bg | `BG; ECHO BGSTATUS:$?` |  |
| PASS | dsh-job-bg-restops-on-tty-read | `WAIT %1; ECHO WAITSTATUS:$?` |  |
| PASS | dsh-job-restopped-listing | `JOBS` |  |
| PASS | dsh-job-slot-two | `CAT &` |  |
| PASS | dsh-job-slot-three | `CAT &` |  |
| PASS | dsh-job-slot-four | `CAT &` |  |
| PASS | dsh-job-table-exhaustion | `CAT &; ECHO STATUS:$?` |  |
| PASS | dsh-comment-boundary | `ECHO COMMENTOK # IGNORED` |  |
| PASS | dsh-quoted-operator-literal | `ECHO "AND" "!" "&"` |  |
| PASS | dsh-adjacent-quoted-fragments | `ECHO AB"CD"'EF'` |  |
| PASS | dsh-escaped-hash-literal | `ECHO A\#B` |  |
| PASS | dsh-glob-relative-no-match | `ECHO DSH-NONEXISTENT-*` |  |
| PASS | dsh-glob-quoted-question | `ECHO "/SYSTEM/DSHG?"` |  |
| PASS | dsh-control-if-failure-branch | `IF FALSE THEN ECHO WRONG ELSE ECHO RIGHT FI` |  |
| PASS | dsh-status-or-fallback | `FALSE OR ECHO FALLBACK` |  |
| PASS | dsh-status-and-skip | `FALSE AND ECHO WRONG; ECHO RIGHT` |  |
