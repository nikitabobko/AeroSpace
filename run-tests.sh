#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/check-uncommitted-files.sh

./build-debug.sh -Xswiftc -warnings-as-errors
./run-swift-test.sh

./.debug/airlock -h > /dev/null
./.debug/airlock --help > /dev/null
./.debug/airlock -v | grep -q "0.0.0-SNAPSHOT SNAPSHOT"
./.debug/airlock --version | grep -q "0.0.0-SNAPSHOT SNAPSHOT"

./lint.sh --check-uncommitted-files
./generate.sh
./script/check-uncommitted-files.sh

echo
echo "✅ All tests have passed successfully"
