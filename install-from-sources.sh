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

brew list airlock-dev-user/airlock-dev-tap/airlock-dev > /dev/null 2>&1 && brew uninstall airlock-dev-user/airlock-dev-tap/airlock-dev # Compatibility. Drop after a while
brew list nikitabobko/local-tap/airlock-dev > /dev/null 2>&1 && brew uninstall nikitabobko/local-tap/airlock-dev
brew list airlock > /dev/null 2>&1 && brew uninstall airlock
which brew-install-path > /dev/null 2>&1 || brew install nikitabobko/tap/brew-install-path

# Override HOMEBREW_CACHE. Otherwise, homebrew refuses to "redownload" the snapshot file
# Maybe there is a better way, I don't know
rm -rf /tmp/airlock-from-sources-brew-cache
HOMEBREW_CACHE=/tmp/airlock-from-sources-brew-cache brew install-path ./.release/airlock-dev.rb

rm -rf "$(brew --prefix)/Library/Taps/airlock-dev-user" # Compatibility. Drop after a while
