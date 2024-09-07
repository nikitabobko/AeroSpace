#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

# ./build-debug.sh || exit 125 # `git bisect run` compatible
swift test

./run-cli.sh -h
./run-cli.sh -v

./script/install-deps.sh --swiftlint
./swift-exec-deps/.build/debug/swiftlint lint --quiet

./script/install-deps.sh --swiftformat
./swift-exec-deps/.build/debug/swiftformat .

./generate.sh --all
./script/check-uncommitted-files.sh
