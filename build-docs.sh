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
        for file in aerospace*.adoc; do
            mv "$file" "flightdeck${file#aerospace}"
        done

        sed -E -i '' \
            -e 's/AeroSpace/FlightDeck/g' \
            -e 's/aerospace/flightdeck/g' \
            -e 's|github.com/nikitabobko/FlightDeck|github.com/nikitabobko/AeroSpace|g' \
            -e 's|nikitabobko.github.io/FlightDeck|nikitabobko.github.io/AeroSpace|g' \
            flightdeck*.adoc util/man-attributes.adoc

        bundler exec asciidoctor -b manpage flightdeck*.adoc

        # Comment by AI:
        #   gman (the g Dai client) renders bare .~ and /~ as ligatures (~ becomes ˜).
        #   We use groff's \[ti] escape (which produces a literal tilde) instead.
        #   Note: escaping .~ in asciidoc via pass:[] doesn't work because asciidoctor
        #   converts \\ to \(rs) before groff sees the input.
        sed -E -i '' 's|\.~|\.\\[ti]|g; s|/~|/\\[ti]|g' flightdeck-test.1

        rm -rf -- *.adoc
    cd - > /dev/null
}

build-site
build-man
