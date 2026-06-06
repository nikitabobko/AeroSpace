#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

# Usage: ./build-docs.sh [man]
# Mintlify builds and deploys the documentation site from docs/.
mode="${1:-man}"
if [[ "$mode" != "man" && "$mode" != "all" ]]; then
    echo "Usage: $0 [man]" >&2
    exit 1
fi

node ./script/generate-command-docs.mjs
