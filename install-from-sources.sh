#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

rebuild=1
while test $# -gt 0; do
    case $1 in
        --dont-rebuild) rebuild=0; shift ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

if test $rebuild == 1; then
    ./build-release.sh
fi

brew list aerospace-dev > /dev/null 2>&1 && brew uninstall aerospace-dev
brew list aerospace > /dev/null 2>&1 && brew uninstall aerospace

rm -rf /tmp/aerospace-from-sources-brew-cache

cask_dir="$(brew --prefix)/Library/Taps/aerospace-dev-user/homebrew-aerospace-dev-tap/Casks/"
mkdir -p "$cask_dir"
cp ./.release/aerospace-dev.rb "$cask_dir"
# Override HOMEBREW_CACHE. Otherwise, homebrew refuses to "redownload" the snapshot file
# Maybe there is a better way, I don't know
env HOMEBREW_CACHE=/tmp/aerospace-from-sources-brew-cache brew install --cask aerospace-dev-user/aerospace-dev-tap/aerospace-dev
