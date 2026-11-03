# DAIMOS SIMH runtime report

## Summary

- Total probes: 35
- PASS: 35
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
