#!/usr/bin/env bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

cd "$(dirname "$0")"

./generate.sh
xcodebuild -scheme AeroSpace build -configuration Debug # no clean because it may lead to accessibility permission loss
xcodebuild -scheme AeroSpace-cli build -configuration Debug # no clean because it may lead to accessibility permission loss

rm -rf .debug && mkdir .debug
pushd ~/Library/Developer/Xcode/DerivedData > /dev/null
    if [ "$(ls | grep AeroSpace | wc -l)" -ne 1 ]; then
        echo "Found several AeroSpace dirs in $(pwd)"
        ls | grep AeroSpace
        exit 1
    fi
popd > /dev/null
cp -r ~/Library/Developer/Xcode/DerivedData/AeroSpace*/Build/Products/Debug/AeroSpace-Debug.app .debug
cp -r ~/Library/Developer/Xcode/DerivedData/AeroSpace*/Build/Products/Debug/aerospace-debug .debug
