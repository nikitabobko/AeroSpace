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

PATH="$PATH:$(brew --prefix)/bin"
export PATH

brew list aerospace-dev-user/aerospace-dev-tap/aerospace-dev > /dev/null 2>&1 && brew uninstall aerospace-dev-user/aerospace-dev-tap/aerospace-dev # Compatibility. Drop after a while
brew list nikitabobko/local-tap/aerospace-dev > /dev/null 2>&1 && brew uninstall nikitabobko/local-tap/aerospace-dev
brew list aerospace > /dev/null 2>&1 && brew uninstall aerospace
which brew-install-path > /dev/null 2>&1 || brew install nikitabobko/tap/brew-install-path

# Override HOMEBREW_CACHE. Otherwise, homebrew refuses to "redownload" the snapshot file
# Maybe there is a better way, I don't know
rm -rf /tmp/aerospace-from-sources-brew-cache
HOMEBREW_CACHE=/tmp/aerospace-from-sources-brew-cache brew install-path ./.release/aerospace-dev.rb

rm -rf "$(brew --prefix)/Library/Taps/aerospace-dev-user" # Compatibility. Drop after a while
