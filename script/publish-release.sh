#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

build_version=""
cask_git_repo_path=""
site_git_repo_path=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --cask-git-repo-path) cask_git_repo_path="$2"; shift 2;;
        --site-git-repo-path) site_git_repo_path="$2"; shift 2;;
        *) echo "Unknown option $1"; exit 1;;
    esac
done

if test -z "$build_version"; then
    echo "--build-version flag is mandatory" > /dev/stderr
    exit 1
fi

if ! test -d "$cask_git_repo_path"; then
    echo "--cask-git-repo-path is a mandatory flag that must point to existing directory" > /dev/stderr
    exit 1
fi

if ! test -d "$site_git_repo_path"; then
    echo "--site-git-repo-path is a mandatory flag that must point to existing directory" > /dev/stderr
    exit 1
fi

./run-tests.sh
./build-release.sh --build-version "$build_version" --configuration Release

git tag -a "v$build_version" -m "v$build_version" && git push git@github.com:nikitabobko/AeroSpace.git "v$build_version"
link="https://github.com/nikitabobko/AeroSpace/releases/new?tag=v$build_version"
open "$link" || { echo "$link"; exit 1; }
sleep 1
open -R "./.release/AeroSpace-v$build_version.zip"

echo "Please upload .zip to GitHub release and hit Enter"
read -r

./script/build-brew-cask.sh \
    --cask-name aerospace \
    --zip-uri "https://github.com/nikitabobko/AeroSpace/releases/download/v$build_version/AeroSpace-v$build_version.zip" \
    --build-version "$build_version"

eval "$cask_git_repo_path/pin.sh"
cp .release/aerospace.rb "$cask_git_repo_path/Casks/aerospace.rb"

rm -rf "${site_git_repo_path:?}/*" # https://www.shellcheck.net/wiki/SC2115
cp .site/* "$site_git_repo_path"
