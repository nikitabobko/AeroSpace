#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/install-dep.sh --bundler

rm -rf .site && mkdir .site
rm -rf .man && mkdir .man

cp-docs() {
    cp -r ./docs/*.adoc "$1"
    cp -r ./docs/assets "$1"
    cp -r ./docs/util "$1"
    cp -r ./docs/config-examples "$1"
}

build-site() {
    cp-docs ./.site
    cp ./docs/index.html ./.site

    cd .site
        # Delete "flightdeck " prefix in command synopses embedded in the website.
        sed -E -i '' '/tag::synopsis/, /end::synopsis/ s/^(flightdeck | {10})//' aerospace*
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
        for file in aerospace*.adoc; do
            mv "$file" "flightdeck${file#aerospace}"
        done

        # Source filenames retain the upstream aerospace-* prefix for easier rebases.
        # Generated manpage filenames and includes use the public flightdeck command.
        sed -E -i '' 's|include::(\./)?aerospace-|include::\1flightdeck-|g' flightdeck*.adoc

        bundler exec asciidoctor -b manpage flightdeck*.adoc

        # gman renders bare .~ and /~ as ligatures, so use groff's literal tilde.
        sed -E -i '' 's|\.~|\.\\[ti]|g; s|/~|/\\[ti]|g' flightdeck-test.1

        rm -rf -- *.adoc
    cd - > /dev/null
}

build-site
build-man
