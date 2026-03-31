#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/check-uncommitted-files.sh

./build-debug.sh -Xswiftc -warnings-as-errors
./run-swift-test.sh

./.debug/airlock -h > /dev/null
./.debug/airlock --help > /dev/null
expected_version="$(cat VERSION) SNAPSHOT"
./.debug/airlock -v | grep -qF "$expected_version"
./.debug/airlock --version | grep -qF "$expected_version"

./lint.sh --check-uncommitted-files
./generate.sh
./script/check-uncommitted-files.sh

echo
echo "✅ All tests have passed successfully"
