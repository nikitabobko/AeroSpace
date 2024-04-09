#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

brew uninstall aerospace || true
./build-release.sh
rm -rf /Applications/AeroSpace.app
cp -r .release/AeroSpace.app /Applications
mkdir -p ~/.bin
cp .release/aerospace ~/.bin
