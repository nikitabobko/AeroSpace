#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./run-tests.sh
./build-release.sh

version=$(head -1 ./version.txt | awk '{print $1}')
git tag -a v$version -m "v$version" && git push git@github.com:nikitabobko/AeroSpace.git v$version
open "https://github.com/nikitabobko/AeroSpace/releases/new?tag=v$version"
open -R ./.release/AeroSpace-v$version.zip
