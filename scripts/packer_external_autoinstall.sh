#!/bin/sh
set -e -u
set -x

sed_command=''

OLDIFS="$IFS"
IFS='='
while read -r template_key template_value; do
    sed_command="${sed_command+ $sed_command;} s@\${$template_key}@$template_value@g"
done
IFS="$OLDIFS"

sed -e "${sed_command}" ./templates/install.conf.tmpl > ./packer_httproot/install.conf