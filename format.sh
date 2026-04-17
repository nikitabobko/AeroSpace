#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/install-dep.sh --swiftformat
./.deps/swiftformat/swiftformat .
