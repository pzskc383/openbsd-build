#!/bin/sh

lynx -listonly -dump https://www.openbsd.org/ftp.html |grep pub/OpenBSD|awk '{print $2}' > mirrors
netselect -s5 -t30 $(sed 's@^.*//\([^/]*\)/.*$@\1@' mirrors| sort -u) |awk '{print $2}' > topten
echo mirror list:
while read -r host; do echo "$(grep $host mirrors)"; echo ; done < topten
rm mirrors topten 2>/dev/null
