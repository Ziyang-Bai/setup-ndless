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

retry_git() {
  local attempt
  for attempt in 1 2 3 4; do
    if "$@"; then
      return 0
    fi
    if [[ "$attempt" != 4 ]]; then
      echo "Git operation failed (attempt $attempt/4); retrying." >&2
      sleep $((attempt * 5))
    fi
  done
  return 1
}

clone_complete=0
for attempt in 1 2 3 4; do
  rm -rf "$install_dir"
  if git clone --filter=blob:none --no-checkout "$repository" "$install_dir"; then
    clone_complete=1
    break
  fi
  if [[ "$attempt" != 4 ]]; then
    echo "Ndless clone failed (attempt $attempt/4); retrying." >&2
    sleep $((attempt * 5))
  fi
done
if [[ "$clone_complete" != 1 ]]; then
  echo "Unable to clone Ndless after four attempts." >&2
  exit 1
fi
retry_git git -C "$install_dir" fetch --depth=1 origin "$revision"
git -C "$install_dir" checkout --detach FETCH_HEAD
git -C "$install_dir" submodule sync --recursive
retry_git git -C "$install_dir" submodule update --init --recursive

sdk="$install_dir/ndless-sdk"
toolchain="$sdk/toolchain"
export PARALLEL="-j$jobs"

system_wget="$(command -v wget)"
retry_bin="$(mktemp -d)"
trap 'rm -rf "$retry_bin"' EXIT
cat > "$retry_bin/wget" <<EOF
#!/usr/bin/env bash
set -euo pipefail
real_wget="$system_wget"
options=(--tries=5 --timeout=45 --waitretry=10 --retry-connrefused --retry-on-http-error=429,500,502,503,504)
if "\$real_wget" "\${options[@]}" "\$@"; then
  exit 0
fi
arguments=("\$@")
changed=0
for ((index = 0; index < \${#arguments[@]}; ++index)); do
  if [[ "\${arguments[index]}" == https://ftpmirror.gnu.org/gnu/* ]]; then
    arguments[index]="https://ftp.gnu.org/gnu/\${arguments[index]#https://ftpmirror.gnu.org/gnu/}"
    changed=1
  fi
done
if [[ "\$changed" == 1 ]]; then
  echo "Primary GNU mirror failed; retrying through ftp.gnu.org." >&2
  exec "\$real_wget" "\${options[@]}" "\${arguments[@]}"
fi
exit 1
EOF
chmod +x "$retry_bin/wget"
export PATH="$retry_bin:$PATH"

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

export PATH="$toolchain/install/bin:$sdk/bin:$PATH"

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
