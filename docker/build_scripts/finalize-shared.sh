#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

# disable some pip warnings
export PIP_ROOT_USER_ACTION=ignore
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_WARN_SCRIPT_LOCATION=0
export PIP_CACHE_DIR=/tmp/pip_cache/

for PREFIX in /opt/shared-cpython*; do
	# Some python's install as bin/python3. Make them available as bin/python
	if [ -e "${PREFIX}/bin/python3" ] && [ ! -e "${PREFIX}/bin/python" ]; then
		ln -s python3 "${PREFIX}/bin/python"
	fi
	PY_VER=$("${PREFIX}/bin/python" -c "import sys; print('.'.join(str(v) for v in sys.version_info[:2]))")
	PY_GIL=$("${PREFIX}/bin/python" -c "import sysconfig; print('t' if sysconfig.get_config_vars().get('Py_GIL_DISABLED', 0) else '')")

	# Install pinned packages for this python version.
	# Use the already installed non-shared cpython pip to bootstrap pip
	"/usr/local/bin/cpython${PY_VER}" -m pip --python "${PREFIX}/bin/python" install -U --require-hashes -r "${MY_DIR}/requirements${PY_VER}.txt"

	if [ -e "${PREFIX}/bin/pip3" ] && [ ! -e "${PREFIX}/bin/pip" ]; then
		ln -s pip3 "${PREFIX}/bin/pip"
	fi

	# Make versioned python commands available directly in environment.
	# Don't use symlinks: c.f. https://github.com/python/cpython/issues/106045
	cat <<EOF > "/usr/local/bin/py${PY_VER}${PY_GIL}"
#!/bin/sh
exec "${PREFIX}/bin/python" "\$@"
EOF
	chmod +x "/usr/local/bin/py${PY_VER}${PY_GIL}"
done

# remove cache
rm -rf /tmp/* || true
