#!/bin/bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

# Look for a given dependency, failing the whole script if not found.
# If found, create a mapping script to that dependency in the .deps/bin folder
add-to-bin() {
    /usr/bin/which "$1" &> /dev/null || (echo "Dependency $1 not found" && exit 1)
    
    cat > ".deps/bin/${2:-$1}" <<EOF
#!/bin/bash
exec '$(/usr/bin/which "$1")' "\$@"
EOF
}

# Delete the dependency mapping scripts from .deps/bin, recreate them,
# and establish our PATH with .deps/bin in it
nuke-path() {
    /bin/rm -rf .deps/bin
    /bin/mkdir -p .deps/bin

    add-to-bin bash not-outdated-bash # build-shell-completion.sh
    add-to-bin brew # install-from-sources.sh
    add-to-bin bundle # Ruby, asciidoc
    add-to-bin bundler # Ruby, asciidoc
    add-to-bin cargo
    add-to-bin fish
    add-to-bin git
    add-to-bin rustc
    add-to-bin xcbeautify

    export PATH="${PWD}/.deps/bin:/bin:/usr/bin"
    chmod +x .deps/bin/*
}

if [ -z "${NUKE_PATH:-}" ]; then
    export NUKE_PATH=1
    nuke-path
fi

xcodebuild() {
    # Mute stderr
    # 2024-02-12 23:48:11.713 xcodebuild[60777:7403664] [MT] DVTAssertions: Warning in /System/Volumes/Data/SWE/Apps/DT/BuildRoots/BuildRoot11/ActiveBuildRoot/Library/Caches/com.apple.xbs/Sources/IDEFrameworks/IDEFrameworks-22269/IDEFoundation/Provisioning/Capabilities Infrastructure/IDECapabilityQuerySelection.swift:103
    # Details:  createItemModels creation requirements should not create capability item model for a capability item model that already exists.
    # Function: createItemModels(for:itemModelSource:)
    # Thread:   <_NSMainThread: 0x6000037202c0>{number = 1, name = main}
    # Please file a bug at https://feedbackassistant.apple.com with this warning message and any useful information you can provide.
    if /usr/bin/which xcbeautify &> /dev/null; then
        /usr/bin/xcodebuild "$@" 2>&1 | xcbeautify --quiet # Only print tasks that have warnings or errors
    else
        /usr/bin/xcodebuild "$@" 2>&1
    fi
}
