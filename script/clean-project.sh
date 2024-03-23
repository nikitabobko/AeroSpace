#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

rm -rf AeroSpace.xcodeproj
./generate.sh
xcodebuild clean
rm -rf .build
rm -rf .xcode-build
rm -rf ~/Library/Developer/Xcode/DerivedData/AeroSpace-*
