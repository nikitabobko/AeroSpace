#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

build_version=""
tap_git_repo_path="${FLIGHTDECK_HOMEBREW_TAP_PATH:-$HOME/src/homebrew-tap}"
team_id="${FLIGHTDECK_TEAM_ID:-2ZPA772V9V}"
codesign_identity="${DEVELOPER_ID_APPLICATION:-}"
notary_profile="${FLIGHTDECK_NOTARY_PROFILE:-flightdeck-notary}"
run_tests=1
while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --tap-git-repo-path) tap_git_repo_path="$2"; shift 2;;
        --team-id) team_id="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        --notary-profile) notary_profile="$2"; shift 2;;
        --skip-tests) run_tests=0; shift 1;;
        *) echo "Unknown option $1"; exit 1;;
    esac
done

if test -z "$codesign_identity"; then
    codesign_identity="Developer ID Application: Saad Bash ($team_id)"
fi

if test -z "$build_version"; then
    echo "--build-version flag is mandatory" > /dev/stderr
    exit 1
fi

if ! test -d "$tap_git_repo_path/Casks"; then
    echo "--tap-git-repo-path must point to a Homebrew tap with a Casks directory" > /dev/stderr
    exit 1
fi

if test "$run_tests" = 1; then
    ./test.sh
fi

./build-release.sh \
    --build-version "$build_version" \
    --team-id "$team_id" \
    --codesign-identity "$codesign_identity" \
    --notary-profile "$notary_profile" \
    --notarize

release_zip="FlightDeck-v$build_version.zip"
release_url="https://github.com/saadjs/FlightDeck/releases/download/v$build_version/$release_zip"

./script/build-brew-cask.sh \
    --cask-name flightdeck \
    --zip-uri ".release/$release_zip" \
    --cask-zip-uri "$release_url" \
    --build-version "$build_version"

cp -r .release/flightdeck.rb "$tap_git_repo_path/Casks/flightdeck.rb"

echo
echo "Release artifact: .release/$release_zip"
echo "Tap cask: $tap_git_repo_path/Casks/flightdeck.rb"
echo "Upload .release/$release_zip to $release_url before pushing the tap update."
