#!/bin/sh
set -e -u
set -x

disklabel_file="$(cat|head -n1)"

if [ -f "$disklabel_file" ]; then
    cat "$disklabel_file" > ./packer_httproot/disklabel.txt
    echo >> ./packer_httproot/disklabel.txt
fi