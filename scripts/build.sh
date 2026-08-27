#!/usr/bin/env bash
set -Eeuo pipefail

repository="https://github.com/ndless-nspire/Ndless.git"
install_dir="${INSTALL_DIR:?INSTALL_DIR is required}"
revision="${NDLESS_REVISION:?NDLESS_REVISION is required}"
requested_jobs="${INPUT_JOBS:-0}"

if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]] || [[ "$(basename "$install_dir")" != "$revision" ]]; then
  echo "Refusing to build into an unvalidated installation directory." >&2
  exit 1
fi
if [[ ! "$requested_jobs" =~ ^[0-9]+$ ]]; then
  echo "jobs must be a non-negative integer." >&2
  exit 1
fi
if [[ "$requested_jobs" == "0" ]]; then
  jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc)"
else
  jobs="$requested_jobs"
fi
if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
  echo "Unable to determine a valid build job count." >&2
  exit 1
fi

rm -rf "$install_dir"
git clone --filter=blob:none --no-checkout "$repository" "$install_dir"
git -C "$install_dir" fetch --depth=1 origin "$revision"
git -C "$install_dir" checkout --detach FETCH_HEAD
git -C "$install_dir" submodule sync --recursive
git -C "$install_dir" submodule update --init --recursive

sdk="$install_dir/ndless-sdk"
toolchain="$sdk/toolchain"
export PARALLEL="-j$jobs"

echo "Building Ndless toolchain with $jobs parallel job(s)."
if ! (
  cd "$toolchain"
  CXX="g++ -std=c++11" CXXFLAGS="-std=c++11" ./build_toolchain.sh
); then
  echo "The GCC 14/libcody compatibility pass stopped; resuming with default C++ flags."
  (
    cd "$toolchain"
    env -u CXX -u CXXFLAGS PARALLEL="$PARALLEL" ./build_toolchain.sh
  )
fi

export PATH="$toolchain/install/bin:$sdk/bin:$sdk/tools/zehn:$PATH"

echo "Building Ndless SDK libraries and tools."
if ! make -C "$sdk" -j"$jobs"; then
  echo "The SDK build stopped; rebuilding FreeType with the known system-zlib configuration."
  make -C "$sdk/thirdparty/freetype2" clean
  make -C "$sdk/thirdparty/freetype2" \
    CC=nspire-gcc \
    "T=-c -o " \
    "ANSIFLAGS=-O2 -Wall -Wextra -DFT_CONFIG_OPTION_SYSTEM_ZLIB" \
    SYSTEM_ZLIB=yes \
    library
  make -C "$sdk" -j"$jobs"
fi

printf '%s\n' "$revision" > "$install_dir/.setup-ndless-complete"
rm -rf "$toolchain/download"
echo "Ndless SDK build completed at $sdk"
