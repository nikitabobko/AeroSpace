#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

# --ignore-cmd-help :
#   It takes 300ms for cmd-help to generate. It's too long to run in build-debug.sh, that's why we ignore it
./generate.sh --ignore-xcodeproj --ignore-cmd-help
swift build --build-tests "$@"

rm -rf .debug && mkdir .debug
cp -r .build/debug/aerospace .debug
cp -r .build/debug/AeroSpaceApp .debug
