#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./generate.sh
xcodebuild -scheme AeroSpace build -configuration Debug -derivedDataPath .xcode-build
xcodebuild -scheme AeroSpace-Tests build -configuration Debug -derivedDataPath .xcode-build
cd LocalPackage
    swift build
cd - > /dev/null

rm -rf .debug && mkdir .debug
cp -r .xcode-build/Build/Products/Debug/AeroSpace-Debug.app .debug
cp -r LocalPackage/.build/debug/aerospace .debug
