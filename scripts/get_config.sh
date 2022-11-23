#!/bin/bash
# create by wangcc,20221121 
set -e -x

echo "Creating init catalogue "

mkdir -p /etc/init.d/


# info logs the given argument at info log level.
info() {
    echo "[INFO] " "$@"
}

# warn logs the given argument at warn log level.
warn() {
    echo "[WARN] " "$@" >&2
}

# fatal logs the given argument at fatal log level.
fatal() {
    echo "[ERROR] " "$@" >&2
    if [ -n "${SUFFIX}" ]; then
        echo "[ALT] Please visit 'https://github.com/wangcc7/Configuration-upload' directly and download the " >&2
    fi
    exit 1
}
# setup_env defines needed environment variables.
setup_env() {
    INSTALL_CONFIGURATION_GITHUB_URL="https://github.com/wangcc7/Configuration-upload"
    # --- bail if we are not root ---
    if [ ! $(id -u) -eq 0 ]; then
        fatal "You need to be root to perform this install"
    fi
}

# setup_arch set arch and suffix,
# fatal if architecture not supported.
setup_arch() {
    case ${ARCH:=$(uname -m)} in
    amd64)
        ARCH=amd64
        SUFFIX=${ARCH}
        ;;
    x86_64)
        ARCH=amd64
        SUFFIX=${ARCH}
        ;;
    *)
        fatal "unsupported architecture ${ARCH}"
        ;;
    esac
}

# verify_downloader verifies existence of
# network downloader executable.
verify_downloader() {
    cmd="$(command -v "${1}")"
    if [ -z "${cmd}" ]; then
        return 1
    fi
    if [ ! -x "${cmd}" ]; then
        return 1
    fi

    # Set verified executable as our downloader program and return success
    DOWNLOADER=${cmd}
    return 0
}

# setup_tmp creates a temporary directory
# and cleans up when done.
setup_tmp() {
    TMP_DIR=$(mktemp -d -t continue-install.XXXXXXXXXX)
    TMP_CHECKSUMS=${TMP_DIR}/continue.checksums
    TMP_TARBALL=${TMP_DIR}/continue.tarball
    cleanup() {
        code=$?
        set +e
        trap - EXIT
        rm -rf "${TMP_DIR}"
        exit $code
    }
    trap cleanup INT EXIT
}

# --- use desired CONFIGURATION version if defined or find version from channel ---
get_release_version() {
   ## INSTALL_CONFIGURATION_GITHUB_URL
    if [ -n "${INSTALL_CONFIGURATION_VERSION}" ]; then
        version=${INSTALL_CONFIGURATION_VERSION}
    else
        info "finding release for channel ${INSTALL_CONFIGURATION_CHANNEL}"
        INSTALL_CONFIGURATION_CHANNEL_URL=""
        version_url="${INSTALL_CONFIGURATION_CHANNEL_URL}/${INSTALL_CONFIGURATION_CHANNEL}"
        case ${DOWNLOADER} in
        *curl)
            version=$(${DOWNLOADER} -w "%{url_effective}" -L -s -S ${version_url} -o /dev/null | sed -e 's|.*/||')
            ;;
        *wget)
            version=$(${DOWNLOADER} -SqO /dev/null ${version_url} 2>&1 | grep -i Location | sed -e 's|.*/||')
            ;;
        *)
            fatal "Unsupported downloader executable '${DOWNLOADER}'"
            ;;
        esac
        INSTALL_CONFIGURATION_VERSION="${version}"
    fi
    info "using ${INSTALL_CONFIGURATION_VERSION} as release"
}

# download downloads from github url.
download() {
    if [ $# -ne 2 ]; then
        fatal "download needs exactly 2 arguments"
    fi

    case ${DOWNLOADER} in
    *curl)
        curl -o "$1" -fsSL "$2"
        ;;
    *wget)
        wget -qO "$1" "$2"
        ;;
    *)
        fatal "downloader executable not supported: '${DOWNLOADER}'"
        ;;
    esac

    # Abort if download command failed
    if [ $? -ne 0 ]; then
        fatal "download failed"
    fi
}

# download_tarball downloads binary from github url.
download_tarball() {
    TARBALL_URL=${INSTALL_CONFIGURATION_GITHUB_URL}/releases/download/${INSTALL_CONFIGURATION_VERSION}/rancherd-${SUFFIX}.tar.gz
    info "downloading tarball at ${TARBALL_URL}"
    download "${TMP_TARBALL}" "${TARBALL_URL}"
}

# verify_tarball verifies the downloaded installer checksum.
verify_tarball() {
    info "verifying installer"
    CHECKSUM_ACTUAL=$(sha256sum "${TMP_TARBALL}" | awk '{print $1}')
    if [ "${CHECKSUM_EXPECTED}" != "${CHECKSUM_ACTUAL}" ]; then
        fatal "download sha256 does not match ${CHECKSUM_EXPECTED}, got ${CHECKSUM_ACTUAL}"
    fi
}

unpack_tarball() {
    info "unpacking tarball file"
    mkdir -p /usr/local
    tar xzf $TMP_TARBALL -C /usr/local
}

do_install_tar() {
    verify_downloader curl || verify_downloader wget || fatal "can not find curl or wget for downloading files"
    setup_tmp
    get_release_version
    download_checksums
    download_tarball
    verify_tarball
    unpack_tarball
}

do_install() {
    setup_env
    setup_arch
    do_install_tar
}

## this is main
do_install