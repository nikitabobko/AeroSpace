#!/usr/bin/env bash
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

# I'd not need this script if `swift run` wasn't that damn slow compared to `swift build`!
# https://forums.swift.org/t/swift-run-really-slow/67807/12
cd "$(dirname "$0")"

cd ./LocalPackage
    output="$(swift build)"
    if [ $? -ne 0 ]; then
        echo "$output"
        exit 1
    fi
cd - > /dev/null

set -e # Exit if one of commands exit with non-zero exit code

./LocalPackage/.build/debug/aerospace "$@"
