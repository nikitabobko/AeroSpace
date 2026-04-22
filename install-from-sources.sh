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

brew install --cask ./.release/aerospace-dev.rb

rm -rf "$(brew --prefix)/Library/Taps/aerospace-dev-user" # Compatibility. Drop after a while
