#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./build-debug.sh
swift test

./.debug/aerospace -h > /dev/null
./.debug/aerospace --help > /dev/null
./.debug/aerospace -v | grep -q "0.0.0-SNAPSHOT SNAPSHOT"
./.debug/aerospace --version | grep -q "0.0.0-SNAPSHOT SNAPSHOT"

./script/install-dep.sh --swiftlint
./.deps/swiftlint/swiftlint lint --quiet

./script/install-dep.sh --swiftformat
./.deps/swiftformat/swiftformat .

./generate.sh --all
./script/check-uncommitted-files.sh
