#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./generate.sh --ignore-xcodeproj
swift build

rm -rf .debug && mkdir .debug
cp -r .build/debug/aerospace .debug
cp -r .build/debug/AeroSpaceApp .debug
