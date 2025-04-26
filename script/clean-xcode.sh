#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

./script/check-uncommitted-files.sh

git clean -ffxd
rm -rf ~/Library/Developer/Xcode/DerivedData/AeroSpace-*
rm -rf ./.xcode-build

rm -rf AeroSpace.xcodeproj
./generate.sh
