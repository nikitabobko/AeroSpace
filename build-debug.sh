#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./generate.sh --ignore-xcodeproj
swift build ${swift_build_args[@]+"${swift_build_args[@]}"} # https://stackoverflow.com/questions/7577052/unbound-variable-error-in-bash-when-expanding-empty-array
swift build ${swift_build_args[@]+"${swift_build_args[@]}"} --target AppBundleTests # swift build doesn't build test targets by default :(

rm -rf .debug && mkdir .debug
cp -r .build/debug/aerospace .debug
cp -r .build/debug/AeroSpaceApp .debug
