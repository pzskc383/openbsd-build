#!/bin/sh

TMPDIR=$(mktemp -d)
cvs -d "$1" -q up -rHEAD -Pd  2>"$TMPDIR/err.log" >/dev/null
cvsstatus=$?

if ! [ $cvsstatus -eq 0 ]; then
  while read -r line ; do

    if echo "$line"|grep -qF 'cvs update: move away'; then
      rm "$(echo "$line"|sed 's@.*away \([^;]*\);.*$@\1@')"
    else
      echo "$line" >> "$TMPDIR/fail.log"
    fi
  done < "$TMPDIR/err.log"
fi

if [ "$2" = fail ]; then
  [ -e "$TMPDIR/fail.log" ] && cat "$TMPDIR/fail.log"
  rm -rf "$TMPDIR"
  exit $cvsstatus
else
  exec "$0" "$@" "fail"
fi
