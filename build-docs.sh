#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

adoc_site_args=()
while test $# -gt 0; do
    case "$1" in
        --release)
            adoc_site_args+=(--attribute relfilesuffix) # Drop html suffix in links
            shift;;
        *) echo "Unknown arg $1" > /dev/stderr; exit 1;;
    esac
done

./script/install-dep.sh --bundler

rm -rf .site && mkdir .site
rm -rf .man && mkdir .man

cp-docs() {
    cp -r ./docs/*.adoc "$1"
    cp -r ./docs/assets "$1"
    cp -r ./docs/util "$1"
    cp -r ./docs/config-examples "$1"
    cp ./docs/docinfo-footer.html "$1"
}

build-site() {
    cp-docs ./.site
    cp ./docs/index.html ./.site

    cd .site
        # Delete "aerospace " prefifx in synopsis
        sed -E -i '' '/tag::synopsis/, /end::synopsis/ s/^(aerospace | {10})//' aerospace*
        bundler exec asciidoctor \
            "${adoc_site_args[@]}" \
            ./guide.adoc \
            ./commands.adoc \
            ./goodies.adoc
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

        # Comment by AI:
        #   gman (the g Dai client) renders bare .~ and /~ as ligatures (~ becomes ˜).
        #   We use groff's \[ti] escape (which produces a literal tilde) instead.
        #   Note: escaping .~ in asciidoc via pass:[] doesn't work because asciidoctor
        #   converts \\ to \(rs) before groff sees the input.
        sed -E -i '' 's|\.~|\.\\[ti]|g; s|/~|/\\[ti]|g' aerospace-test.1

        rm -rf -- *.adoc
    cd - > /dev/null
}

build-site
build-man
