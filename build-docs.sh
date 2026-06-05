#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

# Usage: ./build-docs.sh [site|man|all]
# Default: all
mode="${1:-all}"

./script/install-dep.sh --bundler

if [[ "$mode" == "site" || "$mode" == "all" ]]; then
    rm -rf .site && mkdir .site
fi
if [[ "$mode" == "man" || "$mode" == "all" ]]; then
    rm -rf .man && mkdir .man
fi

cp-docs() {
    cp -r ./docs/*.adoc "$1"
    cp -r ./docs/assets "$1"
    cp -r ./docs/util "$1"
    cp -r ./docs/config-examples "$1"
}

build-site() {
    cp-docs ./.site
    # docinfo files must live in the same directory as the processed .adoc files.
    # docinfo.html → injected into <head>; docinfo-header.html → injected after <body>.
    cp ./docs/docinfo.html ./.site/
    cp ./docs/docinfo-header.html ./.site/

    cd .site
        # Delete "flightdeck " prefix in command synopses embedded in the website.
        sed -E -i '' '/tag::synopsis/, /end::synopsis/ s/^(flightdeck | {10})//' aerospace*
        bundler exec asciidoctor \
            --failure-level=WARN \
            ./index.adoc ./guide.adoc ./commands.adoc ./goodies.adoc \
            ./config-reference.adoc ./compatibility.adoc
        cp goodies.html goodness.html # backwards compatibility
        # Add data-pagefind-ignore to pages excluded from the search index
        for f in version.html goodness.html; do
            if test -f "$f"; then
                sed -i '' 's|<body|<body data-pagefind-ignore|' "$f"
            fi
        done
        rm -rf ./*.adoc
        # Remove docinfo fragments after asciidoctor has injected them; they
        # are not standalone HTML pages and would confuse Pagefind.
        rm -f ./docinfo.html ./docinfo-header.html
    cd - > /dev/null

    # Run Pagefind to build the search index (site pages only)
    if command -v npm >/dev/null 2>&1; then
        (
            cd docs
            npm ci --silent 2>/dev/null || npm install --silent
        )
        docs/node_modules/.bin/pagefind \
            --site .site \
            --output-subdir pagefind \
            --quiet
    else
        echo "Warning: npm not found, skipping Pagefind search index"
    fi

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

case "$mode" in
    site) build-site ;;
    man)  build-man  ;;
    all)  build-site; build-man ;;
    *)    echo "Usage: $0 [site|man|all]" >&2; exit 1 ;;
esac
