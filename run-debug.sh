#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./build-debug.sh
./.debug/AeroSpace-Debug.app/Contents/MacOS/AeroSpace-Debug
