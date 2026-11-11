#!/usr/bin/env bash

# The main version. Propagated even to Xcode
SWIFT_TOOLCHAIN_VERSION=6.4.2
# Sets which SwiftPM loads the manifest: swift build from swiftly's toolchain, or the SwiftPM built into Xcode when xcodebuild resolves.
# Sets which PackageDescription APIs the manifest can use.
# This version depends on Xcode/macOS version.
# Unfortunately, Xcode doesn't use SwiftPM from the toolchain.
SWIFT_PACKAGE_MANAGER_MANIFEST_FORMAT=6.4
# Langauge mode. Only the major version counts
SWIFT_LANGAUGE_VERSION=6
MACOS_MIN_DEPLOYMENT_TARGET=13

# Also see:
# - ./Package.swift for runtime dependencies
# - ./script/install-dep.sh for build dependencies
