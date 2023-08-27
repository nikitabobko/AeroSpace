#!/usr/bin/env bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

cd "$(dirname "$0")"

xcodegen # https://github.com/yonaskolb/XcodeGen
xcodebuild -scheme AeroSpace build -configuration Release

rm -rf build && mkdir build
pushd ~/Library/Developer/Xcode/DerivedData > /dev/null
    if [ "$(ls | grep AeroSpace | wc -l)" -ne 1 ]; then
        echo "Found several AeroSpace dirs in $(pwd)"
        ls | grep AeroSpace
        exit 1
    fi
popd > /dev/null
cp -r ~/Library/Developer/Xcode/DerivedData/AeroSpace*/Build/Products/Release/AeroSpace.app build

pushd build
    zip -r AeroSpace.zip AeroSpace.app
popd
