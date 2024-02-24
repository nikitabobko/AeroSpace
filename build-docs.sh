#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

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

    cd .site
        # Delete "aerospace " prefifx in synopsis
        sed -i -E '/tag::synopsis/, /end::synopsis/ s/^(aerospace | {10})//' aerospace*
        asciidoctor *.adoc
        rm -rf *.adoc
        rm -rf aerospace* # Drop man pages
    cd - > /dev/null

    git rev-parse HEAD > .site/version.html
    if [ ! -z "$(git status --porcelain)" ]; then
        echo "git working directory is dirty" >> .site/version.html
    fi
}

build-man() {
    cp-docs .man
    cd .man
        asciidoctor -b manpage aerospace*.adoc
        rm -rf *.adoc
    cd - > /dev/null
}

build-site
build-man
