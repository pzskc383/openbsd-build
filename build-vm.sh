#!/bin/sh

set -e -u

MIRROR_HOST=${MIRROR_HOST:-https://cdn.openbsd.org}
VERSION=${VERSION:-7.8}
BRANCH=${BRANCH:-release}
ARCH=${ARCH:-amd64}
SET_LIST=${SET_LIST:-base}

usage() {
  echo "Usage: $0 [-m mirror ] [-a arch] [-s set_list]"
  echo "[-v openbsd version ] [-b openbsd branch ]"
  echo set lists:
  echo "base: base*.tgz and site*.tgz"
  echo "no-x: base + comp games man"
  echo "full (default): no-x + x- sets"
  echo "ports: full + ports tree"
  echo "src: ports + /usr/src + /usr/xenocara"
  exit 2
}

while getopts "m:v:b:a:s:" opt "$@"; do
  case "$opt" in
    m)
      MIRROR_HOST="${OPTARG}"
      ;;
    v)
      VERSION="${OPTARG}"
      case $VERSION in *.*) ;; *)
        echo "wrong version $VERSION"
        usage; ;;
      esac
      ;;
    b)
      BRANCH="${OPTARG}"
      case $BRANCH in release|current) ;; *)
        echo "wrong branch, must be release or current"
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
    s)
      SET_LIST="${OPTARG}"
      case $SET_LIST in base|no-x|full|ports|src) ;; *)
        echo "set lists: base|no-x|full|ports|src"
        usage; ;;
      esac
      ;;
    ?)
      ;;
  esac
done

SHORTVERSION="$(echo "$VERSION"|tr -d .)"

if [ "$BRANCH" = current ]; then
  FTP_TAG=snapshots
else
  FTP_TAG=$VERSION
fi

INSTALL_IMG_NAME="cd${SHORTVERSION}.iso"
MIRROR_BASE="pub/OpenBSD/${FTP_TAG}"

cp packer/install.sh packer_httproot/i
mkdir -p packer_httproot/mirror/source
(
  cd packer_httproot/mirror/source
  for s in src sys xenocara ports; do
    test -f "${s}.tar.gz" || \
      { wget -c "$MIRROR_HOST/$MIRROR_BASE/${s}.tar.gz"; sleep 2; }
  done
)
mkdir -p "packer_httproot/mirror/${ARCH}"
(
  cd "packer_httproot/mirror/${ARCH}"
  for s in bsd bsd.rd bsd.mp ${INSTALL_IMG_NAME} "INSTALL.${ARCH}" SHA256; do
    test -f "${s}" || \
      { wget -c "$MIRROR_HOST/$MIRROR_BASE/${ARCH}/${s}"; sleep 2; }
  done
  for s in base comp game man xbase xfont xserv xshare; do
    test -f "${s}${SHORTVERSION}.tgz" || \
      { wget -c "$MIRROR_HOST/$MIRROR_BASE/${ARCH}/${s}${SHORTVERSION}.tgz"; sleep 2; }
  done
  mv SHA256 SHA256.orig; sort -u < SHA256.orig > SHA256; rm SHA256.orig
  install_site=../../../packer_site/install.site
  # echo "#!/bin/sh" > "$install_site"
  # echo "set -e -u" >> "$install_site"
  # echo "pkg_add rsync" >> "$install_site"
  # echo "echo \"$(head -n1 ../../../packer/vagrant-keys/vagrant.pub.ed25519)\" >> /root/.ssh/authorized_keys" \
  #   >> "$install_site"
  chmod 0700 "$install_site"
  bsdtar -c --uid 0 --gid 0 -C  ../../../packer_site/ -f - ./|gzip > "site${SHORTVERSION}.tgz"
  ls -lt > index.txt
)


if [ -d ./output ]; then
  echo cleaning old output.
  rm -rf ./output
fi

if ! [ -d ./iso ]; then
  echo creating iso directory.
  mkdir -p ./iso
fi



echo running packer.

export CHECKPOINT_DISABLE=1 # don't phone home
[ -t 1 ] || { PACKER_NO_COLOR=1; export PACKER_NO_COLOR; }

export PACKER_LOG=0
export PACKER_DEBUG= #-debug
export PACKER_LIBVIRT_STREAM_CONSOLE=1

export PKR_VAR_obsd_arch="${ARCH}"
export PKR_VAR_obsd_cd_image="${INSTALL_IMG_NAME}"
export PKR_VAR_obsd_set_list="${SET_LIST}"


templatefile=obsd-build.pkr.hcl

echo "Build start : $(date)"
packer validate "$templatefile" && \
packer build ${PACKER_DEBUG}  "$templatefile"

if [ $? -eq 0 ]; then
  mv ./output/obsd-build ./output/obsd-build.qcow2
  echo build successful.

fi
