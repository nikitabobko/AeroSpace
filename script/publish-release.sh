#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

build_version=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-version)
            build_version="$2"
            shift
            shift
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

if [ -z "$build_version" ]; then
    echo "--build-version flag is mandatory" > /dev/stderr
    exit 1
fi

./run-tests.sh
./build-release.sh --build-version "$build_version"

git tag -a v$build_version -m "v$build_version" && git push git@github.com:nikitabobko/AeroSpace.git v$build_version
link="https://github.com/nikitabobko/AeroSpace/releases/new?tag=v$build_version"
open "$link" || { echo "$link"; exit 1; }
sleep 1
open -R ./.release/AeroSpace-v$build_version.zip
