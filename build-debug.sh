#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

# --ignore-cmd-help :
#   It takes 300ms for cmd-help to generate. It's too long to run in build-debug.sh, that's why we ignore it
./generate.sh --ignore-xcodeproj --ignore-cmd-help
swift build --build-tests "$@"
bin_path="$(swift build "$@" --show-bin-path)"

rm -rf .debug && mkdir .debug
cp -r "$bin_path/aerospace" .debug
cp -r "$bin_path/AeroSpaceApp" .debug
