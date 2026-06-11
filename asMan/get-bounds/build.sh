#!/bin/zsh
# asman-build
# Compiles asman-get-bounds.swift into a binary and installs it next to asman.
# Run from anywhere; all paths are resolved relative to this script's location.
#
# Usage:
#   ./asman-build          # build and install
#   ./asman-build clean    # remove compiled binary

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
SRC="${SCRIPT_DIR}/asman-get-bounds.swift"
# Install the binary one level up (bin/) next to the asman script itself,
# so chezmoi can manage it as a regular executable file.
OUT="${SCRIPT_DIR}/../asman-get-bounds"

build() {
  echo "Compiling ${SRC} -> ${OUT}" >&2
  swiftc "${SRC}" \
    -framework Cocoa \
    -framework Foundation \
    -O \
    -o "${OUT}"
  echo "Done: ${OUT}" >&2
}

clean() {
  if [[ -f "${OUT}" ]]; then
    rm -f "${OUT}"
    echo "Removed ${OUT}" >&2
  else
    echo "Nothing to clean." >&2
  fi
}

case "${1:-build}" in
  build)  build  ;;
  clean)  clean  ;;
  *)
    echo "Usage: $0 [build|clean]" >&2
    exit 1
    ;;
esac
