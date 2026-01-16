#!/bin/sh

set -e -u
set -x

errdie() {
    printf "%s\n" "$*"
    exit 1
}

cd "${PACKER_BOX_OUTPUT_DIR}/${PACKER_BOX_NAME}" ||  errdie "can't cd to $PACKER_BOX_OUTPUT_DIR"

PACKER_BOX_TYPE="${PACKER_BOX_NAME#*.}"
PACKER_BOX_ARCH="${PACKER_BOX_NAME%.*}"

BOX_DIR=$(pwd)/box_dir

rm -rf "${BOX_DIR}" && mkdir "${BOX_DIR}"
qemu-img convert -f raw -O qcow2 -m 2 -c -o compression_type=zstd "${PACKER_BOX_IMAGE}" "${BOX_DIR}"/box.img

BOX_NAME="${PACKER_BOX_IMAGE}-${PACKER_BOX_TYPE}"

cat <<EOF | sed -e "s/__DISKSIZE__/${PACKER_BOX_SIZE}/;" > "${BOX_DIR}"/metadata.json
{
    "provider": "libvirt",
    "format": "qcow2",
    "virtual_size": __DISKSIZE__
}
EOF

cat <<EOF > "${BOX_DIR}"/info.json
{
}
EOF

cp "${PACKER_BOX_TEMPLATE_DIR}/Vagrantfile.${PACKER_BOX_ARCH}.rb" "${BOX_DIR}"/Vagrantfile

tar -C "${BOX_DIR}"/ cv \
    ./metadata.json ./info.json ./Vagrantfile ./box.img | \
    pigz -9 > \
    "${BOX_NAME}.box"

vagrant box add -f \
  --provider libvirt \
  -a "$PACKER_BOX_ARCH" \
  --name "$BOX_NAME" \
  "$BOX_NAME".box