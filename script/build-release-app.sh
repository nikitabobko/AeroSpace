#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

build_info_file='' # mandatory
build_version="0.0.0-SNAPSHOT"
codesign_identity="aerospace-codesign-certificate"
while test $# -gt 0; do
    case $1 in
        --build-info-file) build_info_file="$2"; shift 2;;
        --build-version) build_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        *) echo "Unknown arg $1" > /dev/stderr; exit 1;;
    esac
done

if test -z "$build_info_file"; then echo "--build-info-file is mandatory" > /dev/stderr; exit 1; fi

cd ./xcode
    xcode_configuration="Release"
    /usr/bin/xcrun xcodebuild -version
    /usr/bin/xcrun xcodebuild clean build \
        -scheme AeroSpace \
        -destination "generic/platform=macOS" \
        -configuration "$xcode_configuration" \
        -derivedDataPath .xcode-build \
        MARKETING_VERSION="$build_version" \
        AEROSPACE_CODE_SIGN_IDENTITY="$codesign_identity" \
        AEROSPACE_BUILD_INFO_LDFLAGS="-sectcreate __TEXT __aero_build $build_info_file"
cd -

cp -r "xcode/.xcode-build/Build/Products/$xcode_configuration/AeroSpace.app" .release
