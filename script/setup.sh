#!/usr/bin/env bash

setup() {
    set -e # Exit if one of commands exit with non-zero exit code
    set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
    set -o pipefail # Any command failed in the pipe fails the whole pipe
    # set -x # Print shell commands as they are executed (or you can try -v which is less verbose)
    tmp=(
        $(brew --prefix)/opt/asciidoctor/bin
        $(brew --prefix)/opt/gsed/libexec/gnubin
        $(brew --prefix)/opt/tree/bin
        $(brew --prefix)/opt/xcodegen/bin
        /bin # bash
        /usr/bin # xcodebuild, zip
    )

    IFS=':'
    export PATH=${tmp[*]}
    unset IFS
}

if [ -z "$SETUP_SH" ]; then
    export SETUP_SH=true
    setup
fi
