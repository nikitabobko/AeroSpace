#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./build-release.sh
rm -rf /Applications/AeroSpace.app
cp -r .release/AeroSpace.app /Applications
mkdir -P ~/.bin
cp .release/aerospace ~/.bin
