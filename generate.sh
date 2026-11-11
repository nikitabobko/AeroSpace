#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

# The main version. Propagated even to Xcode
SWIFT_TOOLCHAIN_VERSION=6.4.2
# Sets which SwiftPM loads the manifest: swift build from swiftly's toolchain, or the SwiftPM built into Xcode when xcodebuild resolves.
# Sets which PackageDescription APIs the manifest can use.
# This version depends on Xcode/macOS version.
# Unfortunately, Xcode doesn't use SwiftPM from the toolchain.
SWIFT_PACKAGE_MANAGER_MANIFEST_FORMAT=6.2
# Langauge mode. Only the major version counts
SWIFT_LANGAUGE_VERSION=6
MACOS_MIN_DEPLOYMENT_TARGET=13

generate_xcodeproj=1
generate_cmd_help=1
while test $# -gt 0; do
    case $1 in
        --ignore-cmd-help) generate_cmd_help=0; shift 1 ;;
        --ignore-xcodeproj) generate_xcodeproj=0; shift 1 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

echo $SWIFT_TOOLCHAIN_VERSION > ./.swift-version

sed -i '' "1s|.*|// swift-tools-version: ${SWIFT_PACKAGE_MANAGER_MANIFEST_FORMAT}|" Package.swift
sed -i '' "/#MACOS_MIN_DEPLOYMENT_TARGET/ s|platforms: .*|platforms: [.macOS(.v${MACOS_MIN_DEPLOYMENT_TARGET})], // #MACOS_MIN_DEPLOYMENT_TARGET|" Package.swift

if test $generate_cmd_help = 1; then
    # It takes 300ms for the script to complete
    ./script/generate-cmd-help.sh
fi

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
