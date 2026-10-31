#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

./script/check-uncommitted-files.sh

rm -rf ~/Library/Developer/Xcode/DerivedData/AeroSpace-*
rm -rf ./xcode/.xcode-build

rm -rf ./xcode/AeroSpace.xcodeproj
./generate.sh
