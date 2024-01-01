#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

# I'd not need this script if `swift run` wasn't that damn slow compared to `swift build`!
# https://forums.swift.org/t/swift-run-really-slow/67807/12
cd ./LocalPackage
    output="$(swift build)"
    if [ $? -ne 0 ]; then
        echo "$output"
        exit 1
    fi
cd - > /dev/null

set -e # Exit if one of commands exit with non-zero exit code

./LocalPackage/.build/debug/aerospace "$@"
