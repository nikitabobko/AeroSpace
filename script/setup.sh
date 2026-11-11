#!/usr/bin/env bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe

if ! /bin/test -z "${AEROSPACE_VERBOSE_BUILD:-}"; then
    set -x # Print shell commands as they are executed (or you can try -v which is less verbose)
fi

if ! grep -q '^5\.' <<< "$BASH_VERSION"; then
    echo "Your bash version is too old. Version 5 is the minimum required version" > /dev/stderr
    exit 1
fi

add-optional-dep-to-bin() {
    if /usr/bin/which "$1" &> /dev/null; then
        file=".deps/bin/${2:-$1}"
        > "$file" /bin/echo "#!/bin/bash"
        >> "$file" /bin/echo "exec '$(/usr/bin/which "$1")' \"\$@\""
    fi
}

add-swift-to-bin() {
    if /usr/bin/which swiftly &> /dev/null; then
        file=.deps/bin/swift
        > "$file" /bin/echo "#!/bin/bash"
        # SwiftPM passes -color-diagnostics to swift-frontend even when the output is not a TTY.
        # Without the explicit opt-out, piped output (e.g. \`./build-debug.sh | tee\`) contains escape sequences
        # This is a Swift 6.4 bug. I am just too lazy to report it.
        # I expect that this bug will be fixed in some time without my report anyway
        >> "$file" /bin/echo "if ! /bin/test -t 1; then export NO_COLOR=1; fi"
        >> "$file" /bin/echo "exec '$(/usr/bin/which swiftly)' run swift \"\$@\""
    else
        echo "ERROR: swiftly is not installed." > /dev/stderr
        exit 1
    fi
}

if /bin/test -z "${NUKE_PATH:-}"; then
    /bin/rm -rf .deps/bin
    /bin/mkdir -p .deps/bin

    add-optional-dep-to-bin bash
    add-optional-dep-to-bin fish # build-shell-completion.sh
    add-optional-dep-to-bin rustc # build-shell-completion.sh
    add-optional-dep-to-bin cargo # build-shell-completion.sh
    add-optional-dep-to-bin brew # install-from-sources.sh
    add-optional-dep-to-bin bundle # build-docs.sh
    add-optional-dep-to-bin bundler # build-docs.sh
    add-optional-dep-to-bin git
    add-swift-to-bin
    add-optional-dep-to-bin swiftly

    export PATH="${PWD}/.deps/bin:/bin:/usr/bin"
    chmod +x .deps/bin/*
    export NUKE_PATH=1
fi
