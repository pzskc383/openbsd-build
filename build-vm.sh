#!/bin/sh

set -e -u

VERSION=${VERSION:-7.8}
ARCH=${ARCH:-amd64}
IMG_VARIANT=${IMG_VARIANT:-full}

log() {
  echo "build-vm.sh: $*"
}

usage() {
  echo "Usage: $0 [-a arch: amd64|arm64]"
  echo "[-i img variant: see below]"
  echo "[-v openbsd version: X.Y or 'current' ]"
  echo "img variants:"
  echo "base: base*.tgz and site*.tgz"
  echo "no-x: base + comp games man"
  echo "full (default): no-x + x- sets"
  echo "ports: full + ports tree"
  echo "src: ports + /usr/src + /usr/xenocara"
  echo "cloud: full + cloud-init on a single root partition"
  exit 2
}

while getopts "v:a:i:" opt "$@"; do
  case "$opt" in
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
        base|no-x|full|ports|src|cloud) ;;
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
./scripts/mirror.sh -a "${ARCH}" -v "${VERSION}" "${MIRROR_LOCAL}"

log "re-creating packer httproot"
rm -rf "${HTTP_ROOT}"
mkdir -p "${HTTP_ROOT}"

log "copying install script"
cp ./scripts/server_install.sh "${HTTP_ROOT}"/i

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

log "fetching vagrant-keys"
if ! [ -d "./vagrant-keys" ]; then
  mkdir "./vagrant-keys"
  ./scripts/vagrant_keys.sh ./vagrant-keys
fi

# HCP_CLIENT_SECRET=$(pass vagrantcloud-sp|head -n1)
# HCP_CLIENT_ID=$(pass vagrantcloud-sp |awk -F: '/client_id/{print $2}')
# export HCP_CLIENT_ID HCP_CLIENT_SECRET

export CHECKPOINT_DISABLE=1 # don't phone home
[ -t 1 ] || { PACKER_NO_COLOR=1; export PACKER_NO_COLOR; }

export PACKER_LOG=1
export PACKER_DEBUG= #-debug
export PACKER_LIBVIRT_STREAM_CONSOLE=1

export PKR_VAR_obsd_arch="${ARCH}"
export PKR_VAR_obsd_version="${VERSION}"
export PKR_VAR_obsd_img_variant="${IMG_VARIANT}"

if [ -d "./output" ]; then
  log "cleaning output dir"
  rm -rf "./output"
fi

log running packer.
templatefile=obsd-build.pkr.hcl
packer validate "$templatefile" && \
  packer build ${PACKER_DEBUG}  "$templatefile"
