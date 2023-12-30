#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

rm -rf AeroSpace.xcodeproj
./generate.sh
xcodebuild clean
rm -rf ~/Library/Developer/Xcode/DerivedData/AeroSpace-*
