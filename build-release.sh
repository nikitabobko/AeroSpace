#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

build_version="0.0.0-SNAPSHOT"
codesign_identity="aerospace-codesign-certificate"
while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        *) echo "Unknown option $1" > /dev/stderr; exit 1 ;;
    esac
done

source ./versions.sh
export SWIFTPM_MACOS_MIN_DEPLOYMENT_TARGET=$MACOS_MIN_DEPLOYMENT_TARGET

#############
### BUILD ###
#############

./build-docs.sh --release
./build-shell-completion.sh

./generate.sh
./script/check-uncommitted-files.sh

build_info_file="$PWD/.build-info.txt"
printf '%s\n%s\n%s\n' "$build_version" "$(git rev-parse HEAD)" "$(git rev-parse --short HEAD)" > "$build_info_file"

rm -rf .release && mkdir .release

# Job control puts each build into its own process group, so that the trap kills the whole process tree
set -m

cli_log=$PWD/.release/build-cli.log
app_log=$PWD/.release/build-app.log

echo "$app_log"
echo "$cli_log"

./script/build-release-cli.sh \
    --build-info-file "$build_info_file" \
    --codesign-identity "$codesign_identity" > "$cli_log" 2>&1 &
build_cli_pid=$!

./script/build-release-app.sh \
    --build-info-file "$build_info_file" \
    --build-version "$build_version" \
    --codesign-identity "$codesign_identity" > "$app_log" 2>&1 &
build_app_pid=$!

trap 'kill -- -$build_cli_pid -$build_app_pid 2> /dev/null' EXIT

wait "$build_cli_pid"
wait "$build_app_pid"
trap - EXIT # Remove EXIT trap
set +m

################
### VALIDATE ###
################

./script/validate-release-binaries.sh

############
### PACK ###
############

mkdir -p ".release/AeroSpace-v$build_version/manpage" && cp .man/*.1 ".release/AeroSpace-v$build_version/manpage"
cp -r ./legal ".release/AeroSpace-v$build_version/legal"
cp -r .shell-completion ".release/AeroSpace-v$build_version/shell-completion"
cd .release
    mkdir -p "AeroSpace-v$build_version/bin" && cp -r aerospace "AeroSpace-v$build_version/bin"
    cp -r AeroSpace.app "AeroSpace-v$build_version"
    zip -r "AeroSpace-v$build_version.zip" "AeroSpace-v$build_version"
cd -

#################
### Brew Cask ###
#################
for cask_name in aerospace aerospace-dev; do
    ./script/build-brew-cask.sh \
        --cask-name "$cask_name" \
        --zip-uri ".release/AeroSpace-v$build_version.zip" \
        --build-version "$build_version"
done

############
### Done ###
############
echo
echo "$PWD"/.release/*.zip
