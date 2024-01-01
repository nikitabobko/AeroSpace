#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./generate.sh
xcodebuild -scheme AeroSpace build -configuration Debug # no clean because it may lead to accessibility permission loss
xcodebuild -scheme AeroSpace-Tests build -configuration Debug # no clean because it may lead to accessibility permission loss
cd LocalPackage
    swift build
cd - > /dev/null

rm -rf .debug && mkdir .debug
cd ~/Library/Developer/Xcode/DerivedData
    if [ "$(ls | grep AeroSpace | wc -l)" -ne 1 ]; then
        echo "Found several AeroSpace dirs in $(pwd)"
        ls | grep AeroSpace
        exit 1
    fi
cd - > /dev/null
cp -r ~/Library/Developer/Xcode/DerivedData/AeroSpace*/Build/Products/Debug/AeroSpace-Debug.app .debug
cp -r LocalPackage/.build/debug/aerospace .debug
