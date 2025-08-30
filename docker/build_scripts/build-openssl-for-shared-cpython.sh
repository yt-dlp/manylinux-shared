#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

# Install a more recent openssl
check_var "${OPENSSL_ROOT}"
check_var "${OPENSSL_HASH}"
check_var "${OPENSSL_DOWNLOAD_URL}"

OPENSSL_VERSION=${OPENSSL_ROOT#*-}
PREFIX=/opt/_internal/openssl-${OPENSSL_VERSION%.*}

if [ -d "${PREFIX}" ]; then
	echo "Newest openssl is already built"
	exit 0
fi

if [ "${OS_ID_LIKE}" = "rhel" ];then
	manylinux_pkg_remove openssl-devel
elif [ "${OS_ID_LIKE}" = "debian" ];then
	manylinux_pkg_remove libssl-dev
elif [ "${OS_ID_LIKE}" = "alpine" ]; then
	manylinux_pkg_remove openssl-dev
fi

PARALLEL_BUILDS=
if [ "$(nproc)" -ge 2 ]; then
	PARALLEL_BUILDS=-j2
fi

fetch_source "${OPENSSL_ROOT}.tar.gz" "${OPENSSL_DOWNLOAD_URL}"
check_sha256sum "${OPENSSL_ROOT}.tar.gz" "${OPENSSL_HASH}"
tar -xzf "${OPENSSL_ROOT}.tar.gz"
pushd "${OPENSSL_ROOT}"
./Configure "--prefix=${PREFIX}" "--openssldir=${PREFIX}" --libdir=lib CPPFLAGS="${MANYLINUX_CPPFLAGS}" CFLAGS="${MANYLINUX_CFLAGS}" CXXFLAGS="${MANYLINUX_CXXFLAGS}" LDFLAGS="${MANYLINUX_LDFLAGS} -Wl,-rpath,\$(LIBRPATH)" > /dev/null
make ${PARALLEL_BUILDS} > /dev/null
make install_sw > /dev/null
popd
rm -rf "${OPENSSL_ROOT}" "${OPENSSL_ROOT}.tar.gz"

strip_ "${PREFIX}"

"${PREFIX}/bin/openssl" version
