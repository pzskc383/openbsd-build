#!/bin/sh
set -e -u

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <vagrant-keys-dir>"
    exit 1
fi

output_dir="$1"

cd "$output_dir" || {
    echo "can't cd to ${output_dir}!"
    exit 1
}

for keytype in rsa ed25519; do
    for filetype in key pub; do
        filename="vagrant.${filetype}.${keytype}"
        if ! [ -f "${filename}" ]; then
            wget -c "https://github.com/hashicorp/vagrant/raw/refs/tags/v2.4.9/keys/vagrant.${filetype}.${keytype}"
        fi
    done
done