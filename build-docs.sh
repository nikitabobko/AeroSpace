#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

rm -rf .site && mkdir .site
rm -rf .man && mkdir .man

build_version="0.0.0-SNAPSHOT"
while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        *) echo "Unknown option $1" > /dev/stderr; exit 1 ;;
    esac
done

cp-docs() {
    cp -r docs/*.adoc "$1"
    cp -r docs/assets "$1"
    cp -r docs/util "$1"
    cp -r docs/config-examples "$1"
    sed -i '' "1 s/.*/v$build_version/" "$1/util/site-attributes.adoc"
}

build-site() {
    cp-docs .site

    cd .site
        # Delete "aerospace " prefifx in synopsis
        sed -E -i '' '/tag::synopsis/, /end::synopsis/ s/^(aerospace | {10})//' aerospace*
        bundler exec asciidoctor ./guide.adoc ./commands.adoc ./goodies.adoc
        cp goodies.html goodness.html # backwards compatibility
        rm -rf ./*.adoc
    cd - > /dev/null

    git rev-parse HEAD > .site/version.html
    if ! test -z "$(git status --porcelain)"; then
        echo "git working directory is dirty" >> .site/version.html
    fi
}

build-man() {
    cp-docs .man
    cd .man
        bundler exec asciidoctor -b manpage aerospace*.adoc
        rm -rf -- *.adoc
    cd - > /dev/null
}

build-site
build-man
