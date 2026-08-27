#!/usr/bin/env bash
set -euo pipefail

repository="https://github.com/ndless-nspire/Ndless.git"
ref="${INPUT_NDLESS_REF:-master}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "setup-ndless supports Linux runners only." >&2
  exit 1
fi
if [[ ! "$ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || [[ "$ref" == *..* ]]; then
  echo "Invalid Ndless ref: $ref" >&2
  exit 1
fi
if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
  echo "GITHUB_OUTPUT is not set." >&2
  exit 1
fi

ls_remote_retry() {
  local attempt
  for attempt in 1 2 3 4; do
    if git ls-remote "$@"; then
      return 0
    fi
    if [[ "$attempt" != 4 ]]; then
      echo "Ndless revision lookup failed (attempt $attempt/4); retrying." >&2
      sleep $((attempt * 5))
    fi
  done
  return 1
}

revision=""
if [[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]]; then
  revision="${ref,,}"
else
  branch_revision=""
  tag_revision=""
  peeled_revision=""
  while read -r candidate name; do
    case "$name" in
      "refs/heads/$ref") branch_revision="$candidate" ;;
      "refs/tags/$ref") tag_revision="$candidate" ;;
      "refs/tags/$ref^{}") peeled_revision="$candidate" ;;
    esac
  done < <(ls_remote_retry "$repository" "refs/heads/$ref" "refs/tags/$ref" "refs/tags/$ref^{}")
  revision="${branch_revision:-${peeled_revision:-$tag_revision}}"
fi

if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Unable to resolve Ndless ref '$ref'." >&2
  exit 1
fi

tool_root="${RUNNER_TOOL_CACHE:-$HOME/.cache}/setup-ndless"
install_dir="$tool_root/$revision"
mkdir -p "$tool_root"

{
  echo "revision=$revision"
  echo "install-dir=$install_dir"
} >> "$GITHUB_OUTPUT"

echo "Resolved Ndless '$ref' to $revision"
