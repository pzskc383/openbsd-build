#!/bin/sh
set -e -u

OPENBSD_MIRROR=${OPENBSD_MIRROR:-https://cdn.openbsd.org}

HTTPROOT=""
MIRROR=""
VERSION=""
TEMPLATES=""
SSH_PUBKEY=""

TAGS=""
ARCHES=""

log() {
    echo "httproot: $*" >&2
    logger -t packer-openbsd-mirror "$*"
}

die() {
    log "FATAL: $*"
    exit 1
}


store_var() {
    _tag="$1"
    _key="$2"
    shift 2
    _value="$*"
    _safetag=$(echo "$_tag" | tr '.' '_')
    
    # log "var store: $_tag $_key $_value"
    
    eval "VARIANT_${_safetag}_${_key}=\"\$_value\""

    case " $TAGS " in
        *" $_tag "*) ;;
        *) TAGS="$TAGS $_tag" ;;
    esac

    _arch="${_tag%%.*}"
    case " $ARCHES " in
        *" $_arch "*) ;;
        *) ARCHES="$ARCHES $_arch" ;;
    esac
}

get_var() {
    _tag="$1"
    _key="$2"
    _safetag=$(echo "$_tag" | tr '.' '_')
    # log "var get: $_tag $_key $_value"

    eval "echo \"\$VARIANT_${_safetag}_${_key}\""
}


download() {
    _url="$1"
    _target="$2"
    wget -q -O "${_target}" -c -t 0 "${_url}"
}

get_sha(){
    _filename="$1"
    _sumfile="${2-./SHA256}"
    awk -F' = ' "/\(${_filename}\)/{ print \$2 }" "$_sumfile" |head -n1
}

check_sha() {
    _filename="$1"
    _sha256="$(get_sha "$_filename")"
    printf "SHA256 (%s) = %s\n" "$_filename" "$_sha256" | sha256sum -c --status
}

check_sha_and_download() {
    _filename="$1"
    _baseurl="$2"

    if [ ! -f "${_filename}" ]; then
        log "downloading ${_filename} (missing)"
        download "${_baseurl}/${_filename}" "$_filename"
    fi

    if ! check_sha "$_filename"; then
        log "downloading ${_filename} (checksum mismatch)"
        download "${_baseurl}/${_filename}" "$_filename"
    fi
}

mirror_source() {
    _version="$1"
    _basedir="$2"
    _baseurl="${OPENBSD_MIRROR}/pub/OpenBSD/${_version}"

    log "mirroring sources for OpenBSD/${_version}"
    mkdir -p "${_basedir}"
    (
        cd "${_basedir}" || die "cannot cd to ${_basedir}"
        download "${_baseurl}/SHA256" "./SHA256"
        download "${_baseurl}/SHA256.sig" "./SHA256.sig"
        for s in src sys xenocara ports; do
            check_sha_and_download "${s}.tar.gz" "${_baseurl}"
        done
    )
}

mirror_sets() {
    _version="$1"
    _arch="$2"
    _basedir="$3"
    _baseurl="${OPENBSD_MIRROR}/pub/OpenBSD/${_version}/${_arch}"
    _sv=$(echo "$_version" | tr -d .)

    log "mirroring sets for OpenBSD/${_version}/${_arch}"
    mkdir -p "${_basedir}"
    (
        cd "${_basedir}" || die "cannot cd to ${_basedir}"
        download "${_baseurl}/SHA256" "./SHA256"
        download "${_baseurl}/SHA256.sig" "./SHA256.sig"

        for fn in bsd bsd.rd bsd.mp "cd${_sv}.iso" "INSTALL.${_arch}" BUILDINFO; do
            check_sha_and_download "${fn}" "${_baseurl}"
        done

        for set in base comp game man xbase xfont xserv xshare; do
            check_sha_and_download "${set}${_sv}.tgz" "${_baseurl}"
        done
    )
}

mirror_syspatch() {
    _version="$1"
    _arch="$2"
    _basedir="$3"
    _baseurl="${OPENBSD_MIRROR}/pub/OpenBSD/syspatch/${_version}/${_arch}"

    log "mirroring syspatches for OpenBSD/${_version}/${_arch}"
    mkdir -p "${_basedir}"
    (
        cd "${_basedir}" || die "cannot cd to ${_basedir}"
        download "${_baseurl}/SHA256" "./SHA256"
        download "${_baseurl}/SHA256.sig" "./SHA256.sig"

        # shellcheck disable=SC2013
        for p in $(sed 's@.*(@@; s@).*@@' < ./SHA256); do
            check_sha_and_download "${p}" "${_baseurl}"
        done
    )
}


while read -r first second rest; do
    [ -z "$first" ] && continue

    case "$first" in
        config)
            case "$second" in
                httproot)       HTTPROOT="$rest" ;;
                mirror)         MIRROR="$rest" ;;
                version)        VERSION="$rest" ;;
                templates)      TEMPLATES="$rest" ;;
                ssh_pubkey)     SSH_PUBKEY="$rest" ;;
                openbsd_mirror) OPENBSD_MIRROR="$rest" ;;
                *) log "unknown config: $second" ;;
            esac
            ;;
        *.*)
            store_var "$first" "$second" "$rest"
            ;;
        *)
            log "ignoring line: $first $second $rest"
            ;;
    esac
done


[ -z "$HTTPROOT" ] && die "httproot not set"
[ -z "$MIRROR" ] && die "mirror not set"
[ -z "$VERSION" ] && die "version not set"
[ -z "$TEMPLATES" ] && die "templates not set"
[ -z "$SSH_PUBKEY" ] && die "ssh_pubkey not set"

SHORT_VERSION="$(echo "$VERSION"|tr -d .)"
ISO_FILENAME="cd${SHORT_VERSION}.iso"

# log "httproot=$HTTPROOT mirror=$MIRROR version=$VERSION"
# log "arches:$ARCHES"
# log "variants:$TAGS"


mirror_source "$VERSION" "$MIRROR/$VERSION"

for arch in $ARCHES; do
    mirror_sets "$VERSION" "$arch" "$MIRROR/$VERSION/$arch"
    mirror_syspatch "$VERSION" "$arch" "$MIRROR/syspatch/$VERSION/$arch"
done


mkdir -p "$HTTPROOT"

SCRIPT_DIR="$(dirname "$0")"
cp "$SCRIPT_DIR/start_install.sh" "$HTTPROOT/i"
chmod +x "$HTTPROOT/i"

mirror_link="$HTTPROOT/mirror"
[ -L "$mirror_link" ] && rm "$mirror_link"
[ -e "$mirror_link" ] || ln -s "$MIRROR" "$mirror_link"


for tag in $TAGS; do
    arch="${tag%%.*}"
    variant="${tag#*.}"

    sets=$(get_var "$tag" "sets")
    disklabel=$(get_var "$tag" "disklabel")

    # log "processing $tag: arch=$arch variant=$variant disklabel=$disklabel"

    arch_dir="$MIRROR/$VERSION/$arch"
    [ -d "$arch_dir" ] || die "arch directory not found: $arch_dir"

    variant_http_dir="$HTTPROOT/variants/$tag"
    mkdir -p "$variant_http_dir"

    sed \
        -e "s|\${ssh_public_key}|$SSH_PUBKEY|g" \
        -e "s|\${server_directory}|mirror/$VERSION/$arch|g" \
        -e "s|\${set_names}|$sets|g" \
        -e "s|\${run_x}|no|g" \
        -e "s|\${default_com0}|no|g" \
        "$TEMPLATES/install.conf.tmpl" > "$variant_http_dir/install.conf"

    disklabel_src="$TEMPLATES/disklabel.${disklabel}.txt"
    [ -f "$disklabel_src" ] || die "disklabel template not found: $disklabel_src"
    cp "$disklabel_src" "$variant_http_dir/disklabel.txt"

    sha256_file="$arch_dir/SHA256"
    [ -f "$sha256_file" ] || die "SHA256 file not found: $sha256_file"

    checksum=$(get_sha "$ISO_FILENAME" "$sha256_file")
    [ -n "$checksum" ] || die "checksum not found for $ISO_FILENAME in $sha256_file"

    iso_path="$arch_dir/$ISO_FILENAME"
    [ -f "$iso_path" ] || die "ISO not found: $iso_path"

    echo "$tag iso_checksum $checksum"
    echo "$tag iso_path $iso_path"
done