#!/usr/bin/env bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

cd "$(dirname "$0")"
rm -rf .site && mkdir .site
rm -rf .man && mkdir .man

cp-docs() {
    cp -r docs/*.adoc $1
    cp -r docs/assets $1
    cp -r docs/util $1
    cp -r docs/config-examples $1
}

build-site() {
    cp-docs .site

    git rev-parse HEAD > .site/version.html
    if [ ! -z "$(git status --porcelain)" ]; then
        echo "git working directory is dirty" >> .site/version.html
    fi

    cd .site
        asciidoctor *.adoc
        rm -rf *.adoc
        rm -rf aerospace* # Drop man pages
    cd -
}

build-man() {
    cp-docs .man
    cd .man
        asciidoctor -b manpage aerospace*.adoc
        rm -rf *.adoc
    cd -
}

build-site
build-man
