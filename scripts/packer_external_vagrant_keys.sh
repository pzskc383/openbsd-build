#!/bin/sh
set -e -u

VAGRANT_VERSION_TAG=v2.4.9
get_key() {
    wget -qc "https://github.com/hashicorp/vagrant/raw/refs/tags/${VAGRANT_VERSION_TAG}/keys/${1}"
}

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <vagrant-keys-dir>"
    exit 1
fi

output_dir="$1"
if ! [ -e "$output_dir" ]; then
    mkdir -p "$output_dir" || {
        echo "failed to mkdir ${output_dir}!"
        exit 1
    }
fi

cd "$output_dir" || {
    echo "can't cd to ${output_dir}!"
    exit 1
}

if [ -f ./sha256sum ]; then
    while read -r sum filename; do
        if ! echo $sum $filename| sha256sum -c --status; then
            rm -f "$filename"
            get_key "$filename"
        fi
    done < ./sha256sum
else
    for keytype in rsa ed25519; do
        for filetype in key pub; do
            filename="vagrant.${filetype}.${keytype}"
            if ! [ -f "${filename}" ]; then
                get_key "$filename"
            fi
        done
    done
    sha256sum vagrant.* > sha256sum
fi


jsoncat() {
    sed ':a;N;$!ba; s@\n@\\n@g; s@"@\\"@g' "$1"
}
fullpath() {
    fn="$1"
    fn="${fn#*/}"
    echo "$(pwd)/${fn}"
}


cat <<EOJSON
{
    "rsa_public": "$(jsoncat ./vagrant.pub.rsa)",
    "rsa_private": "$(fullpath ./vagrant.key.rsa)",
    "ed25519_public": "$(jsoncat ./vagrant.pub.ed25519)",
    "ed25519_private": "$(fullpath ./vagrant.key.ed25519)"
}
EOJSON