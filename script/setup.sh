#!/bin/bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

# Don't forget to also update ./ShellParserGenerated/Package.swift
export antlr_version="4.13.1"

add-optional-dep-to-bin() {
    if /usr/bin/which "$1" &> /dev/null; then
        /bin/cat > ".deps/bin/${2:-$1}" <<EOF
#!/bin/bash
exec '$(/usr/bin/which "$1")' "\$@"
EOF
    fi
}

add-first-available-dep-to-bin() {
    alias_name=$1
    shift
    for tool_name in "$@"; do
        if /usr/bin/which "$tool_name" &> /dev/null; then
            /bin/cat > ".deps/bin/$alias_name" <<EOF
#!/bin/bash
exec '$(/usr/bin/which "$tool_name")' "\$@"
EOF
            return
        fi
    done
}

if /bin/test -z "${NUKE_PATH:-}"; then
    /bin/rm -rf .deps/bin
    /bin/mkdir -p .deps/bin

    add-optional-dep-to-bin bash not-outdated-bash # build-shell-completion.sh
    add-optional-dep-to-bin fish # build-shell-completion.sh
    add-optional-dep-to-bin ruby
    add-optional-dep-to-bin bundle # build-docs.sh
    add-optional-dep-to-bin bundler # build-docs.sh
    add-optional-dep-to-bin antlr4 # script/generate-shell-parser.sh
    add-first-available-dep-to-bin complgen complgen complgen-aarch64-apple complgen-x86_64-apple # build-shell-completion.sh
    add-optional-dep-to-bin xcbeautify # build-release.sh
    add-optional-dep-to-bin swiftformat # format.sh
    add-optional-dep-to-bin swiftlint # format.sh
    add-optional-dep-to-bin xcodegen # generate.sh
    add-optional-dep-to-bin periphery # lint.sh
    add-optional-dep-to-bin git
    add-optional-dep-to-bin swift

    export PATH="${PWD}/.deps/bin:/bin:/usr/bin"
    chmod +x .deps/bin/*
    export NUKE_PATH=1
fi

swift() {
    /usr/bin/env swift "$@"
}

xcodebuild-pretty() {
    log_file="$1"
    shift
    # Mute stderr
    # 2024-02-12 23:48:11.713 xcodebuild[60777:7403664] [MT] DVTAssertions: Warning in /System/Volumes/Data/SWE/Apps/DT/BuildRoots/BuildRoot11/ActiveBuildRoot/Library/Caches/com.apple.xbs/Sources/IDEFrameworks/IDEFrameworks-22269/IDEFoundation/Provisioning/Capabilities Infrastructure/IDECapabilityQuerySelection.swift:103
    # Details:  createItemModels creation requirements should not create capability item model for a capability item model that already exists.
    # Function: createItemModels(for:itemModelSource:)
    # Thread:   <_NSMainThread: 0x6000037202c0>{number = 1, name = main}
    # Please file a bug at https://feedbackassistant.apple.com with this warning message and any useful information you can provide.
    if /usr/bin/which xcbeautify &> /dev/null; then
        /usr/bin/xcrun xcodebuild "$@" 2>&1 | tee "$log_file" | xcbeautify --quiet # Only print tasks that have warnings or errors
        echo "The full unmodified xcodebuild log is saved to $log_file"
    else
        /usr/bin/xcrun xcodebuild "$@" 2>&1 | tee "$log_file"
    fi
}
