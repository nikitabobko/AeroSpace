#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

./script/check-uncommitted-files.sh

rm -rf ~/Library/Developer/Xcode/DerivedData/Airlock-*
rm -rf ./.xcode-build

rm -rf Airlock.xcodeproj
./generate.sh
