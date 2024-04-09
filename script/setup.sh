#!/usr/bin/env bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

setup() {
    BREW_PREFIX="$(brew --prefix)"
    tmp=(
        ${BREW_PREFIX}/opt/asciidoctor/bin
        ${BREW_PREFIX}/opt/gsed/libexec/gnubin
        ${BREW_PREFIX}/opt/tree/bin
        ${BREW_PREFIX}/opt/xcodegen/bin
        ${BREW_PREFIX}/opt/xcbeautify/bin
        ${BREW_PREFIX}/opt/swiftlint/bin
        /bin # bash
        /usr/bin # xcodebuild, zip
    )

    IFS=':'
    export PATH=${tmp[*]}
    unset IFS
}

if [ -z "${SETUP_SH:-}" ]; then
    export SETUP_SH=true
    setup
fi

brew() { "${BREW_PREFIX}/bin/brew" "$@"; }

xcodebuild() {
    # Mute stderr
    # 2024-02-12 23:48:11.713 xcodebuild[60777:7403664] [MT] DVTAssertions: Warning in /System/Volumes/Data/SWE/Apps/DT/BuildRoots/BuildRoot11/ActiveBuildRoot/Library/Caches/com.apple.xbs/Sources/IDEFrameworks/IDEFrameworks-22269/IDEFoundation/Provisioning/Capabilities Infrastructure/IDECapabilityQuerySelection.swift:103
    # Details:  createItemModels creation requirements should not create capability item model for a capability item model that already exists.
    # Function: createItemModels(for:itemModelSource:)
    # Thread:   <_NSMainThread: 0x6000037202c0>{number = 1, name = main}
    # Please file a bug at https://feedbackassistant.apple.com with this warning message and any useful information you can provide.
    /usr/bin/xcodebuild "$@" 2>&1 | xcbeautify --quiet
}
