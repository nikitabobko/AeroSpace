#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

remote="$(git remote -v | grep nikitabobko/AeroSpace | head -1 | awk '{ print $1 }')"
merge_commits="$(git rev-list --merges "$remote/main..HEAD" -- .)"
if ! test -z "$merge_commits"; then
    echo "Merge commits detected. Please prefer rebase"
    exit 1
fi

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
echo "✅ All tests have passed successfully"
