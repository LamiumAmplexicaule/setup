#!/bin/bash
set -eu

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE:-$0}")")
# shellcheck source=utils.sh
. "$SCRIPT_DIR/../../utils.sh"

SUPPORTED_VERSIONS=("20.04" "22.04" "24.04")

# Check platform
OS=$(uname -s)
ARCH=$(uname -m)
if [[ $OS != Linux ]] || [[ $ARCH != x86_64 ]]; then
    echo "Your system is not supported."
    exit 1
fi

# Install dependencies
echo "Install dependencies."
run_as_root apt-get -qq update >/dev/null
run_as_root apt-get -qq -y install wget >/dev/null

# Check version
OS_VERSION=$(sed -n 's/^VERSION_ID="\?\([^"]*\)"\?/\1/p' /etc/os-release)
if ! is_supported_version "$OS_VERSION" "${SUPPORTED_VERSIONS[@]}"; then
    echo "Your os version is not supported."
    exit 1
fi

MOLD_VERSION=$(curl -s https://api.github.com/repos/rui314/mold/releases/latest | jq -r .tag_name)
echo "Mold version: ${MOLD_VERSION#v}"

# Install mold
echo "Install mold."
rm -rf mold
git clone -q https://github.com/rui314/mold.git >/dev/null
cd mold
./install-build-deps.sh >/dev/null
rm -rf build >/dev/null
mkdir -p build >/dev/null
cd build
git checkout -q -b "$MOLD_VERSION" >/dev/null
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=c++ .. >/dev/null
cmake --build . -j $(($(nproc) - 1)) >/dev/null
run_as_root cmake --build build --target install >/dev/null