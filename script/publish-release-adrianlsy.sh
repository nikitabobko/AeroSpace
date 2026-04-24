#!/bin/bash
# Manual release fallback for AdrianLSY/AeroSpace.
# Preferred path is the .github/workflows/release-adrianlsy.yml CI pipeline;
# use this only when the pipeline is unavailable or needs local debugging.
cd "$(dirname "$0")/.."
source ./script/setup.sh

build_version=""
tap_git_repo_path=""
while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --tap-git-repo-path) tap_git_repo_path="$2"; shift 2;;
        *) echo "Unknown option $1"; exit 1;;
    esac
done

if test -z "$build_version"; then
    echo "--build-version flag is mandatory" > /dev/stderr
    exit 1
fi

# Fork versions must match <upstream>-Beta.adrianlsy.<n>
# (mirrors upstream's "-Beta" pre-release marker — this fork is a beta of a beta).
if ! echo "$build_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+-Beta\.adrianlsy\.[0-9]+$'; then
    echo "--build-version must match <upstream>-Beta.adrianlsy.<n>, got: $build_version" > /dev/stderr
    echo "Example: 0.20.0-Beta.adrianlsy.1" > /dev/stderr
    exit 1
fi

if ! test -d "$tap_git_repo_path"; then
    echo "--tap-git-repo-path is a mandatory flag that must point to an existing AdrianLSY/homebrew-tap checkout" > /dev/stderr
    exit 1
fi

./test.sh
./build-release.sh --build-version "$build_version"

git tag -a "v$build_version" -m "v$build_version" && git push git@github.com:AdrianLSY/AeroSpace.git "v$build_version"
link="https://github.com/AdrianLSY/AeroSpace/releases/new?tag=v$build_version"
open "$link" || { echo "$link"; exit 1; }
sleep 1
open -R "./.release/AeroSpace-v$build_version.zip"

echo "Please upload .zip to GitHub release and hit Enter"
read -r

./script/build-brew-cask.sh \
    --cask-name aerospace-adrianlsy \
    --zip-uri "https://github.com/AdrianLSY/AeroSpace/releases/download/v$build_version/AeroSpace-v$build_version.zip" \
    --build-version "$build_version" \
    --homepage "https://github.com/AdrianLSY/AeroSpace"

mkdir -p "$tap_git_repo_path/Casks"
cp -r ".release/aerospace-adrianlsy.rb" "$tap_git_repo_path/Casks/aerospace-adrianlsy.rb"

echo
echo "Cask copied to $tap_git_repo_path/Casks/aerospace-adrianlsy.rb"
echo "Commit + push $tap_git_repo_path manually to complete the release."
