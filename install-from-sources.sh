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
brew list aerospace-dev > /dev/null 2>&1 && brew uninstall aerospace-dev
brew list aerospace > /dev/null 2>&1 && brew uninstall aerospace
brew list "$dev_cask_name" > /dev/null 2>&1 && brew uninstall "$dev_cask_name"
brew list "$primary_cask_name" > /dev/null 2>&1 && brew uninstall "$primary_cask_name"

brew_tap_namespace="$(brew --repository)/Library/Taps/aeroshift-user"
brew_tap_root="$brew_tap_namespace/homebrew-aeroshift-tap"
cleanup-brew-tap() {
    rm -rf "$brew_tap_namespace"
}
trap cleanup-brew-tap EXIT

rm -rf "$brew_tap_namespace"
mkdir -p "$brew_tap_root/Casks"
cp "./.release/$dev_cask_name.rb" "$brew_tap_root/Casks/$dev_cask_name.rb"

HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask "aeroshift-user/aeroshift-tap/$dev_cask_name"
