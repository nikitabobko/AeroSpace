#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./build-debug.sh -Xswiftc -warnings-as-errors
./run-swift-test.sh

./.debug/aerospace -h > /dev/null
./.debug/aerospace --help > /dev/null
./.debug/aerospace -v | grep -q "0.0.0-SNAPSHOT SNAPSHOT"
./.debug/aerospace --version | grep -q "0.0.0-SNAPSHOT SNAPSHOT"

./format.sh
./generate.sh --all
./script/check-uncommitted-files.sh

echo
echo "All tests have passed successfully"
