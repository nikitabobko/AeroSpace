#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

all=0
antlr=0
complgen=0
swiftlint=0
swiftformat=0
xcodegen=0
bundler=0
while test $# -gt 0; do
    case $1 in
        --antlr) antlr=1; shift ;;
        --complgen) complgen=1; shift ;;
        --swiftlint) swiftlint=1; shift ;;
        --xcodegen) xcodegen=1; shift ;;
        --swiftformat) swiftformat=1; shift ;;
        --bundler) bundler=1; shift ;;
        --all) all=1; shift ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

get-marker() { echo ".deps/markers/$1/$(echo "$@" | shasum | awk '{print $1}').marker"; }

create-marker() {
    dir="$(dirname "$1")"
    rm -rf "$dir" && mkdir -p "$dir"
    touch "$1"
}

if test $all == 1 || test $bundler == 1; then
    marker=$(get-marker bundler "$(cat ./Gemfile)" "$(cat ./.bundle/*)")
    if ! test -f "$marker"; then
        bundler install
        create-marker "$marker"
    fi
fi

if test $all == 1 || test $antlr == 1; then
    # https://github.com/antlr/antlr4/releases
    antlr_tools='antlr4-tools==0.2.1'
    marker=$(get-marker antlr $antlr_tools $antlr_version)
    if ! test -f "$marker"; then
        python3 -m venv .deps/python-venv
        source .deps/python-venv/bin/activate
        python3 -m pip install "$antlr_tools"
        create-marker "$marker"
    fi
fi

if test $all == 1 || test $complgen == 1; then
    # https://github.com/adaszko/complgen/releases
    complgen_rev=cacb3970eb
    marker=$(get-marker complgen $complgen_rev)
    if ! test -f "$marker"; then
        cargo install --git https://github.com/adaszko/complgen --rev $complgen_rev --root ./.deps/cargo-root
        create-marker "$marker"
    fi
fi

lazy-download-zip-and-link-bin() {
    artifact_name=$1
    link=$2
    sha=$3
    path_inside_zip=$4

    root_path=".deps/$artifact_name"
    marker_path=$(get-marker "$artifact_name" "$@")

    if ! test -f "$marker_path"; then
        root_dist_path="$root_path/dist"
        zip_name="zip.zip"
        zip_path="$root_dist_path/$zip_name"

        rm -rf "$root_path" && mkdir -p "$root_dist_path"
        curl -L "$link" -o "$zip_path"
        diff --color <(echo "$sha") <(shasum -a 256 "$zip_path")
        (cd "$root_dist_path" && unzip "$zip_name")
        (cd "$root_path" && ln -s "./dist/$path_inside_zip" "$artifact_name")

        create-marker "$marker_path"
    fi
}

if test $all == 1 || test $swiftlint == 1; then
    # https://github.com/realm/SwiftLint/releases
    swiftlint_version=0.59.1
    lazy-download-zip-and-link-bin \
        swiftlint \
        https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/SwiftLintBinary.artifactbundle.zip \
        'b9f915a58a818afcc66846740d272d5e73f37baf874e7809ff6f246ea98ad8a2  .deps/swiftlint/dist/zip.zip' \
        SwiftLintBinary.artifactbundle/swiftlint-$swiftlint_version-macos/bin/swiftlint
fi

if test $all == 1 || test $xcodegen == 1; then
    # https://github.com/yonaskolb/XcodeGen/releases
    xcodegen_version=2.43.0
    lazy-download-zip-and-link-bin \
        xcodegen \
        https://github.com/yonaskolb/XcodeGen/releases/download/$xcodegen_version/xcodegen.artifactbundle.zip \
        'b08135558e9e061440c148a91cc07142a534e99dd8a17bc050a3d30a5b5d340d  .deps/xcodegen/dist/zip.zip' \
        xcodegen.artifactbundle/xcodegen-$xcodegen_version-macosx/bin/xcodegen
fi

if test $all == 1 || test $swiftformat == 1; then
    # https://github.com/nicklockwood/SwiftFormat/releases
    swiftformat_version=0.56.4
    lazy-download-zip-and-link-bin \
        swiftformat \
        https://github.com/nicklockwood/SwiftFormat/releases/download/$swiftformat_version/swiftformat.artifactbundle.zip \
        '8b9c5ce7e3172b7d6f3d5c450495e8fbc5f60e2b80e03dff215cfff36f35425b  .deps/swiftformat/dist/zip.zip' \
        swiftformat.artifactbundle/swiftformat-$swiftformat_version-macos/bin/swiftformat
fi
