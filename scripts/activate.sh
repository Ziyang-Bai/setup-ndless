#!/usr/bin/env bash
set -euo pipefail

install_dir="${INSTALL_DIR:?INSTALL_DIR is required}"
revision="${NDLESS_REVISION:?NDLESS_REVISION is required}"
marker="$install_dir/.setup-ndless-complete"
sdk="$install_dir/ndless-sdk"
toolchain_bin="$sdk/toolchain/install/bin"

if [[ ! -f "$marker" ]] || [[ "$(cat "$marker")" != "$revision" ]]; then
  echo "Ndless installation is incomplete or belongs to another revision." >&2
  exit 1
fi
for directory in "$toolchain_bin" "$sdk/bin"; do
  if [[ ! -d "$directory" ]]; then
    echo "Required Ndless path is missing: $directory" >&2
    exit 1
  fi
done
if [[ -z "${GITHUB_ENV:-}" || -z "${GITHUB_PATH:-}" || -z "${GITHUB_OUTPUT:-}" ]]; then
  echo "GitHub environment output files are not available." >&2
  exit 1
fi

{
  echo "NDLESS_HOME=$sdk"
  echo "NDLESS_SDK=$sdk"
} >> "$GITHUB_ENV"
printf '%s\n' "$toolchain_bin" "$sdk/bin" >> "$GITHUB_PATH"
echo "ndless-home=$sdk" >> "$GITHUB_OUTPUT"

export NDLESS_HOME="$sdk"
export NDLESS_SDK="$sdk"
export PATH="$toolchain_bin:$sdk/bin:$PATH"

arm-none-eabi-gcc --version | sed -n '1p'
nspire-gcc --version | sed -n '1p'
echo "genzehn=$(command -v genzehn)"
echo "make-prg=$(command -v make-prg)"
