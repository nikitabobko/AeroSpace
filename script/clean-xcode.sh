#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

./script/check-uncommitted-files.sh

rm -rf ~/Library/Developer/Xcode/DerivedData/Aeroshift-*
rm -rf ./.xcode-build

rm -rf Aeroshift.xcodeproj
./generate.sh
