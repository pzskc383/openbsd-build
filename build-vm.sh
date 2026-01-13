#!/bin/sh

set -e -u

VERSION=${OPENBSD_VERSION:-7.8}
ARCH=${OPENBSD_ARCH:-amd64}
IMG_VARIANT=${OPENBSD_IMG_VARIANT:-full}
VERBOSE=0

log() {
  echo "build-vm.sh: $*"
}

usage() {
  echo "Usage: $0 [-a arch: amd64|arm64]"
  echo "[-i img variant: see below]"
  echo "[-v openbsd version: X.Y or 'current']"
  echo "[-V : verbose]"
  echo "img variants:"
  echo "base: base*.tgz and site*.tgz"
  echo "nox: base + comp games man"
  echo "full (default): nox + x- sets"
  echo "ports: full + ports tree"
  echo "src: ports + /usr/src + /usr/xenocara"
  echo "cloud: full + cloud-init on a single root partition"
  exit 2
}

while getopts "v:a:i:V" opt "$@"; do
  case "$opt" in
    V)
      VERBOSE=1
      ;;
    v)
      VERSION="${OPTARG}"
      case $VERSION in *.*|currrent) ;; *)
        echo "wrong version $VERSION"
        usage; ;;
      esac
      ;;
    a)
      ARCH="${OPTARG}"
      case $ARCH in amd64|arm64) ;; *)
        echo "arches supported: amd64/arm64"
        usage; ;;
      esac
      ;;
    i)
      IMG_VARIANT="${OPTARG}"
      case $IMG_VARIANT in
        base|nox|full|ports|src|cloud) ;;
        *) usage; ;;
      esac
      ;;
    ?)
      ;;
  esac
done

MIRROR_LOCAL="./ftp_mirror"
HTTP_ROOT="./packer_httproot"

log "mirroring files"
./scripts/packer_ftp_mirror.sh -a "${ARCH}" -v "${VERSION}" "${MIRROR_LOCAL}"

log "re-creating packer httproot"
rm -rf "${HTTP_ROOT}"
mkdir -p "${HTTP_ROOT}"

log "copying install script"
cp ./scripts/start_install.sh "${HTTP_ROOT}"/i

log "copying mirrored sources"
mkdir -p "${HTTP_ROOT}/mirror/${VERSION}"
cp -Rp \
  "${MIRROR_LOCAL}/${VERSION}"/*.tar.gz \
  "${MIRROR_LOCAL}/${VERSION}"/SHA256 "${MIRROR_LOCAL}/${VERSION}"/SHA256.sig \
  "${HTTP_ROOT}/mirror/${VERSION}/"

log "copying mirrored sets"
mkdir -p "${HTTP_ROOT}/mirror/${VERSION}/${ARCH}"
cp -Rp \
  "${MIRROR_LOCAL}/${VERSION}/${ARCH}"/* \
  "${HTTP_ROOT}/mirror/${VERSION}/${ARCH}/"

log "copying mirrored patches"
mkdir -p "${HTTP_ROOT}/mirror/syspatch/${VERSION}/${ARCH}"
cp -Rp \
  "${MIRROR_LOCAL}/syspatch/${VERSION}/${ARCH}"/* \
  "${HTTP_ROOT}/mirror/syspatch/${VERSION}/${ARCH}/"

## HashiCorp Cloud upload
# HCP_CLIENT_SECRET=$(pass vagrantcloud-sp|head -n1)
# HCP_CLIENT_ID=$(pass vagrantcloud-sp |awk -F: '/client_id/{print $2}')
# export HCP_CLIENT_ID HCP_CLIENT_SECRET


export CHECKPOINT_DISABLE=1 # don't phone home
[ -t 1 ] || { PACKER_NO_COLOR=1; export PACKER_NO_COLOR; }

packer_build_cmd='packer build'
packer_validate_cmd='packer build'
if [ "$VERBOSE" -eq 1 ]; then
  PACKER_LOG=1
  PACKER_LIBVIRT_STREAM_CONSOLE=1
  packer_build_cmd="${packer_build_cmd} -debug"
  packer_validate_cmd="${packer_validate_cmd} -debug"
else
  PACKER_LOG=0
  PACKER_LIBVIRT_STREAM_CONSOLE=0
fi
export PACKER_LOG PACKER_LIBVIRT_STREAM_CONSOLE

PKR_VAR_obsd_arch="${ARCH}"
PKR_VAR_obsd_version="${VERSION}"
PKR_VAR_img_variant="${IMG_VARIANT}"
export PKR_VAR_obsd_arch PKR_VAR_obsd_version PKR_VAR_img_variant

if [ -d "./output" ]; then
  log "cleaning output dir"
  rm -rf "./output"
fi

log running packer.

$packer_validate_cmd ./packer/
$packer_build_cmd ./packer/
