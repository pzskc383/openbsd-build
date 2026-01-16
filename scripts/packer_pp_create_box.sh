#!/bin/sh

set -e -u
set -x

errdie() {
    printf "%s\n" "$*"
    exit 1
}

WORKDIR="${PACKER_BOX_OUTPUT_DIR}/${PACKER_BOX_NAME}"

cd "${WORKDIR}" || errdie "can't cd to ${WORKDIR}"

PACKER_BOX_TYPE="${PACKER_BOX_NAME#*.}"
PACKER_BOX_ARCH="${PACKER_BOX_NAME%.*}"

BOX_DIR=$(pwd)/box_dir

rm -rf "${BOX_DIR}" && mkdir "${BOX_DIR}"
qemu-img convert -f raw -O qcow2 -m 2 -c -o compression_type=zstd "${PACKER_BOX_IMAGE}" "${BOX_DIR}"/box.img

BOX_NAME="${PACKER_BOX_IMAGE}-${PACKER_BOX_TYPE}"

cat <<EOF  > "${BOX_DIR}"/metadata.json
{
    "provider": "libvirt",
    "architecture": "__ARCH__",
    "format": "qcow2",
    "virtual_size": __DISKSIZE__
}
EOF
sed -e "s/__DISKSIZE__/${PACKER_BOX_SIZE}/" \
    -e "s/__BOX_NAME__/${BOX_NAME}/" \
    -e "s/__ARCH__/${PACKER_BOX_ARCH}/" \
    -i'' "${BOX_DIR}/metadata.json"

cat <<EOF > "${BOX_DIR}"/info.json
{
}
EOF

cp "${PACKER_BOX_TEMPLATE_DIR}/Vagrantfile.${PACKER_BOX_ARCH}.rb" "${BOX_DIR}"/Vagrantfile

(
    cd "${BOX_DIR}" || errdie "can't cd to ${BOX_DIR}"
    tar c ./metadata.json ./info.json ./Vagrantfile ./box.img | pigz -9 > "${WORKDIR}/${BOX_NAME}.box"
)

BOX_CHECKSUM=$(sha256sum "${WORKDIR}/${BOX_NAME}.box" |awk '{print $1}')

cat <<EOF > "${WORKDIR}/box_metadata.json"
{
  "name": "__BOX_NAME__",
  "description": "__DESCRIPTION__",
  "versions": [
    {
      "version": "__VERSION__",
      "providers": [
        {
          "name": "libvirt",
          "url": "__PATH__",
          "checksum_type": "sha256",
          "checksum": "__CHECKSUM__",
          "architecture": "__ARCH__",
          "default_architecture": true
        }
      ]
    }
  ]
}
EOF

sed -e "s@__BOX_NAME__@${BOX_NAME}@" \
    -e "s@__DESCRIPTION__@${PACKER_BOX_DESCRIPTION}@" \
    -e "s@__VERSION__@${PACKER_BOX_VERSION}@" \
    -e "s@__PATH__@file://${WORKDIR}/${BOX_NAME}.box@" \
    -e "s@__CHECKSUM__@${BOX_CHECKSUM}@" \
    -e "s@__ARCH__@${PACKER_BOX_ARCH}@" \
    -i'' "${WORKDIR}/box_metadata.json"


vagrant box add -f \
  --provider libvirt \
  -a "$PACKER_BOX_ARCH" \
  --name "$BOX_NAME" \
  "${WORKDIR}/box_metadata.json"