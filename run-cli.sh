#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

# I'd not need this script if `swift run` wasn't that damn slow compared to `swift build`!
# https://forums.swift.org/t/swift-run-really-slow/67807/12
cd ./LocalPackage
    swift build > /dev/null || swift build
cd - > /dev/null

./LocalPackage/.build/debug/aerospace "$@"
