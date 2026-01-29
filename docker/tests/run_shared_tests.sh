#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

export PIP_CACHE_DIR=/tmp/pip_cache/

PYTHON_VERSION=
PYTHON_VERSIONS=(
    "3.13"
    "3.14"
)

for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"; do
    # Run upstream tests
    py"${PYTHON_VERSION}" "${MY_DIR}/manylinux-check.py" "${AUDITWHEEL_POLICY}" "${AUDITWHEEL_ARCH}"
    py"${PYTHON_VERSION}" "${MY_DIR}/ssl-check.py"
    py"${PYTHON_VERSION}" "${MY_DIR}/modules-check.py"

    # Test that PyInstaller works
    mkdir -p ./test_pyinstaller
    pushd ./test_pyinstaller
    py"${PYTHON_VERSION}" -m venv ./.venv
    # shellcheck disable=SC1091
    source ./.venv/bin/activate
    # Inside the venv we can use python instead of py3.13 or py3.14 etc
    python -m pip install -U --require-hashes -r "${MY_DIR}/requirements-pyinstaller-${PYTHON_VERSION}.txt"
    mkdir -p test_script
    touch test_script/__init__.py
    cat << EOF > test_script/__main__.py
import os
import platform
import sqlite3
import ssl
import sys


try:
    from compression import zstd
    zstd_version_info = zstd.zstd_version_info
except (ImportError, AttributeError):
    if sys.version_info[:2] >= (3, 14):
        raise
    zstd_version_info = 'unavailable'


def has_correct_glibc(maximum_version):
    version = tuple(map(int, platform.libc_ver()[1].split('.')))
    assert len(version) == 2
    return maximum_version >= version


def main():
    identifier = ' '.join((
        platform.python_implementation(),
        platform.python_version(),
        platform.machine(),
        platform.architecture()[0],
    ))
    print('\n'.join((
        identifier,
        platform.platform(),
        ssl.OPENSSL_VERSION,
        f'sqlite3 {sqlite3.sqlite_version}',
        f'zstd {zstd_version_info}',
    )))
    needed_glibc = {
        'manylinux2014': (2, 17),
        'manylinux_2_28': (2, 28),
        'manylinux_2_31': (2, 31),
    }.get(os.environ['AUDITWHEEL_POLICY'])
    if not needed_glibc or has_correct_glibc(needed_glibc):
        return 0
    print('TEST FAIL: incorrect version of glibc!')
    return 1


if __name__ == '__main__':
    sys.exit(main())
EOF
    python -m PyInstaller --name=test-executable --noconfirm --onefile ./test_script/__main__.py
    chmod +x ./dist/test-executable
    ./dist/test-executable
    popd
    rm -rf ./test_pyinstaller
    deactivate
done

echo "run_shared_tests successful!"
