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

brew_tap_namespace="$(brew --repository)/Library/Taps/aerospace-dev-user"
brew_tap_root="$brew_tap_namespace/homebrew-aerospace-dev-tap"
cleanup-brew-tap() {
    rm -rf "$brew_tap_namespace"
}
trap cleanup-brew-tap EXIT

rm -rf "$brew_tap_namespace"
mkdir -p "$brew_tap_root/Casks"
cp ./.release/aerospace-dev.rb "$brew_tap_root/Casks/aerospace-dev.rb"

HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask aerospace-dev-user/aerospace-dev-tap/aerospace-dev
