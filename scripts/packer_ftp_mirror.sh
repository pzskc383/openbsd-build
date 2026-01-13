#!/bin/sh
set -e -u

OPENBSD_MIRROR=${OPENBSD_MIRROR:-https://cdn.openbsd.org}
VERSION=${VERSION:-7.8}
ARCH=${ARCH:-amd64}

log() {
    echo "ftp_mirror.sh: $*"
}

ensure_dir() {
    dir="$1"
    if ! [ -d "$dir" ]; then
        log "Creating $dir"
        mkdir -p "$dir"
    fi
}

download() {
  url="$1"
  target="$2"
  wget -q -O "${target}" -c -t 0 "${url}"
  # curl -L -o"${target}" -C - "${url}"
}

check_sha() {
  filename="$1"
  awk "/\(${filename}\)/{ print \$0 }" < ./SHA256 |sha256sum -c >/dev/null 2>&1
}

check_sha_and_download() {
  filename="$1"
  baseurl="$2"

  do_download=0
  msg=''
  
  if ! [ -f "${filename}" ]; then
    msg="downloading ${filename} (missing)"
    do_download=1
    download "${baseurl}/${filename}" "$filename"
  fi
  
  if ! check_sha "$filename"; then
    msg="downloading ${filename} (failed checksum)"
    do_download=1
  fi
  
  if [ "$do_download" -eq 1 ]; then
    log "$msg"
    download "${baseurl}/${filename}" "$filename"
  fi
}

download_source() {
  baseurl="$1"
  basedir="$2"
  log "mirrorring sources for OpenBSD/${VERSION}"
  (
    cd "${basedir}" || { echo "cd ${basedir} failed!"; exit 1; }
    
    download "${baseurl}/SHA256" "./SHA256"
    download "${baseurl}/SHA256.sig" "./SHA256.sig"
    for s in src sys xenocara ports; do
      check_sha_and_download "${s}.tar.gz" "${baseurl}"
    done
  )
}

download_sets() {
  baseurl="$1"
  basedir="$2"
  
  log "mirrorring sets for OpenBSD/${VERSION}/${ARCH}"
  (
    cd "${basedir}" || { echo "cd ${basedir} failed!"; exit 1; }
    
    download "${baseurl}/SHA256" "./SHA256"
    download "${baseurl}/SHA256.sig" "./SHA256.sig"

    sv="$(echo "$VERSION"|tr -d .)"

    for fn in bsd bsd.rd bsd.mp "cd${sv}.iso" "INSTALL.${ARCH}" BUILDINFO; do
      check_sha_and_download "${fn}" "${baseurl}"
    done

    for set in base comp game man xbase xfont xserv xshare; do
      check_sha_and_download "${set}${sv}.tgz" "${baseurl}"
    done
  )
}

download_syspatch() {
  baseurl="$1"
  basedir="$2"
  
  log "mirrorring syspatches for OpenBSD/${VERSION}/${ARCH}"
  (
    cd "${basedir}" || { echo "cd ${basedir} failed!"; exit 1; }
    
    download "${baseurl}/SHA256" "./SHA256"
    download "${baseurl}/SHA256.sig" "./SHA256.sig"
    
    # shellcheck disable=2013
    for p in $(sed 's@.*(@@; s@).*@@' < ./SHA256); do
      check_sha_and_download "${p}" "${baseurl}"
    done
  )
}

usage() {
  echo "Usage: $0 [-a arch] [-v openbsd version: *.* or 'current' ] <mirror-directory>"
  exit 2
}

while getopts "a:v:" opt "$@"; do
  case "$opt" in
    a)
      ARCH="${OPTARG}"
      case $ARCH in amd64|arm64) ;; *)
        echo "arches supported: amd64/arm64"
        usage; ;;
      esac
      ;;
    v)
      VERSION="${OPTARG}"
      case $VERSION in
      current)
        echo "mirroring -current isnt supported yet, sorry"
        exit 1
      ;;
      *.*)
      ;;
      *)
        echo "wrong version $VERSION"
        usage;
        ;;
      esac
      ;;
    ?)
      ;;
  esac
done

shift $((OPTIND-1))
if [ "$#" -ne 1 ]; then
    log "Mirror directory is not provided! defaulting to './mirror'"
fi
MIRROR_DIR="${1-./ftp_mirror}"

ensure_dir "${MIRROR_DIR}/${VERSION}"
download_source "${OPENBSD_MIRROR}/pub/OpenBSD/${VERSION}" \
  "${MIRROR_DIR}/${VERSION}"

ensure_dir "${MIRROR_DIR}/${VERSION}/${ARCH}"
download_sets "${OPENBSD_MIRROR}/pub/OpenBSD/${VERSION}/${ARCH}" \
  "${MIRROR_DIR}/${VERSION}/${ARCH}"

ensure_dir "${MIRROR_DIR}/syspatch/${VERSION}/${ARCH}"
download_syspatch "${OPENBSD_MIRROR}/pub/OpenBSD/syspatch/${VERSION}/${ARCH}" \
  "${MIRROR_DIR}/syspatch/${VERSION}/${ARCH}"
