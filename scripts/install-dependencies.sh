#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
  privilege=()
elif command -v sudo >/dev/null 2>&1; then
  privilege=(sudo)
else
  echo "Root privileges or sudo are required to install dependencies." >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Unable to identify the Linux distribution." >&2
  exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
family=" ${ID:-} ${ID_LIKE:-} "

if [[ "$family" == *" debian "* || "$family" == *" ubuntu "* ]]; then
  "${privilege[@]}" apt-get update
  "${privilege[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential git gawk autoconf automake libtool pkg-config \
    libgmp-dev libmpfr-dev libmpc-dev zlib1g-dev libisl-dev libc6-dev \
    texinfo flex bison libncurses-dev wget python3 php-cli python3-dev python3-pip \
    libboost-program-options-dev
elif [[ "$family" == *" fedora "* || "$family" == *" rhel "* ]]; then
  "${privilege[@]}" dnf install -y \
    @development-tools gcc gcc-c++ git gawk autoconf automake libtool pkgconf-pkg-config \
    gmp-devel mpfr-devel libmpc-devel zlib-devel isl-devel \
    libstdc++-static glibc-static texinfo flex bison ncurses-devel \
    wget python3 php-cli python3-devel python3-pip boost-devel
else
  echo "Unsupported Linux distribution: ${PRETTY_NAME:-${ID:-unknown}}" >&2
  echo "Set install-dependencies to false and install the Ndless prerequisites yourself." >&2
  exit 1
fi
