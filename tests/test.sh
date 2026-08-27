#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
bash -n scripts/*.sh

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
output="$temporary/output"
cache="$temporary/cache"

GITHUB_OUTPUT="$output" \
RUNNER_TOOL_CACHE="$cache" \
INPUT_NDLESS_REF=master \
  scripts/resolve.sh

revision="$(sed -n 's/^revision=//p' "$output")"
install_dir="$(sed -n 's/^install-dir=//p' "$output")"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]]
[[ "$install_dir" == "$cache/setup-ndless/$revision" ]]

: > "$output"
GITHUB_OUTPUT="$output" \
RUNNER_TOOL_CACHE="$cache" \
INPUT_NDLESS_REF="$revision" \
  scripts/resolve.sh
[[ "$(sed -n 's/^revision=//p' "$output")" == "$revision" ]]

if GITHUB_OUTPUT="$output" RUNNER_TOOL_CACHE="$cache" INPUT_NDLESS_REF='../invalid' \
    scripts/resolve.sh >/dev/null 2>&1; then
  echo "Invalid refs must be rejected." >&2
  exit 1
fi

sdk="$install_dir/ndless-sdk"
mkdir -p "$sdk/toolchain/install/bin" "$sdk/bin" "$sdk/tools/zehn"
printf '%s\n' "$revision" > "$install_dir/.setup-ndless-complete"
for tool in arm-none-eabi-gcc nspire-gcc genzehn make-prg; do
  case "$tool" in
    arm-none-eabi-gcc) directory="$sdk/toolchain/install/bin" ;;
    genzehn) directory="$sdk/tools/zehn" ;;
    *) directory="$sdk/bin" ;;
  esac
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s test fake"\n' "$tool" > "$directory/$tool"
  chmod +x "$directory/$tool"
done

environment_file="$temporary/environment"
path_file="$temporary/path"
activation_output="$temporary/activation-output"
GITHUB_ENV="$environment_file" \
GITHUB_PATH="$path_file" \
GITHUB_OUTPUT="$activation_output" \
INSTALL_DIR="$install_dir" \
NDLESS_REVISION="$revision" \
  scripts/activate.sh >/dev/null
grep -Fx "NDLESS_HOME=$sdk" "$environment_file"
grep -Fx "NDLESS_SDK=$sdk" "$environment_file"
grep -Fx "ndless-home=$sdk" "$activation_output"
grep -Fx "$sdk/toolchain/install/bin" "$path_file"
grep -Fx "$sdk/bin" "$path_file"
grep -Fx "$sdk/tools/zehn" "$path_file"

if INSTALL_DIR="$install_dir" NDLESS_REVISION="$revision" INPUT_JOBS=invalid \
    scripts/build.sh >/dev/null 2>&1; then
  echo "Invalid job counts must be rejected." >&2
  exit 1
fi

echo "setup-ndless script tests passed"
