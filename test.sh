#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/check-uncommitted-files.sh

./build-debug.sh -Xswiftc -warnings-as-errors
./swift-test.sh

./".debug/$cli_name" -h > /dev/null
./".debug/$cli_name" --help > /dev/null
./".debug/$cli_name" -v | grep -q "0.0.0-SNAPSHOT SNAPSHOT"
./".debug/$cli_name" --version | grep -q "0.0.0-SNAPSHOT SNAPSHOT"

./lint.sh --check-uncommitted-files
./generate.sh
./script/check-uncommitted-files.sh

echo
echo "✅ All tests have passed successfully"
