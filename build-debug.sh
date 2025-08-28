#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

# It takes 300ms for cmd-help to generate. It's too long to run in build-debug.sh, that's why we ignore it
./generate.sh --ignore-xcodeproj --ignore-cmd-help
swift build "$@"
swift build --target AppBundleTests "$@" # swift build doesn't build test targets by default :(

rm -rf .debug && mkdir .debug
cp -r .build/debug/aerospace .debug
cp -r .build/debug/AeroSpaceApp .debug
