#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

source ./versions.sh

generate_xcodeproj=1
while test $# -gt 0; do
    case $1 in
        --ignore-xcodeproj) generate_xcodeproj=0; shift 1 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

echo $SWIFT_TOOLCHAIN_VERSION > ./.swift-version

cp Package.swift .swap-Package.swift
sed -i '' "1s|.*|// swift-tools-version: ${SWIFT_PACKAGE_MANAGER_MANIFEST_FORMAT}|" .swap-Package.swift
if ! cmp -s -- .swap-Package.swift Package.swift; then mv -- .swap-Package.swift Package.swift; fi

./script/generate-cmd-help.sh
./script/generate-subcommand-descriptions.sh

if test $generate_xcodeproj = 1; then
    export XCODEGEN_DEPLOYMENT_TARGET=$MACOS_MIN_DEPLOYMENT_TARGET
    export XCODEGEN_SWIFT_VERSION=$SWIFT_LANGAUGE_VERSION

    ./script/install-dep.sh --xcodegen
    cd xcode

    # Use the same Swift toolchain in xcodebuild
    XCODEGEN_TOOLCHAINS="$(plutil -extract CFBundleIdentifier raw "$(swiftly use --print-location)/Info.plist")"
    export XCODEGEN_TOOLCHAINS
    ../.deps/xcodegen/xcodegen # https://github.com/yonaskolb/XcodeGen
fi
