#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./build-debug.sh > /dev/stderr
./.debug/aerospace "$@"
