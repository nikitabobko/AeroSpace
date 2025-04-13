#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./generate.sh --ignore-xcodeproj
_swift build
_swift build --target AppBundleTests # swift build doesn't build test targets by default :(

rm -rf .debug && mkdir .debug
cp -r .build/debug/aerospace .debug
cp -r .build/debug/AeroSpaceApp .debug
