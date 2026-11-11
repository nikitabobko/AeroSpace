#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./generate.sh --ignore-xcodeproj
swift build --build-tests "$@"
bin_path="$(swift build "$@" --show-bin-path)"

rm -rf .debug && mkdir .debug
cp -r "$bin_path/aerospace" .debug
cp -r "$bin_path/AeroSpaceApp" .debug

############
### Done ###
############
echo
printf '%s\n' "$PWD"/.debug/*
