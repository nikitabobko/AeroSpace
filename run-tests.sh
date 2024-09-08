#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

# ./build-debug.sh || exit 125 # `git bisect run` compatible
swift test

./run-cli.sh -h
./run-cli.sh -v

./script/install-dep.sh --swiftlint
./.deps/swiftlint/swiftlint lint --quiet

./script/install-dep.sh --swiftformat
./.deps/swiftformat/swiftformat .

./generate.sh --all
./script/check-uncommitted-files.sh
