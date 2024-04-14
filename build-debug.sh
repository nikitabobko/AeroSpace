#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./generate.sh "$@"
swift build
xcodebuild -scheme AeroSpace build -configuration Debug -derivedDataPath .xcode-build

rm -rf .debug && mkdir .debug
cp -r .xcode-build/Build/Products/Debug/AeroSpace-Debug.app .debug
cp -r .build/debug/aerospace .debug
