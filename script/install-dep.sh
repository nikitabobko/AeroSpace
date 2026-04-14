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
periphery=0
while test $# -gt 0; do
    case $1 in
        --antlr) antlr=1; shift ;;
        --complgen) complgen=1; shift ;;
        --swiftlint) swiftlint=1; shift ;;
        --xcodegen) xcodegen=1; shift ;;
        --swiftformat) swiftformat=1; shift ;;
        --bundler) bundler=1; shift ;;
        --periphery) periphery=1; shift ;;
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
    swiftlint_version=0.63.2
    lazy-download-zip-and-link-bin \
        swiftlint \
        https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/SwiftLintBinary.artifactbundle.zip \
        '12befab676fc972ffde2ec295d016d53c3a85f64aabd9c7fee0032d681e307e9  .deps/swiftlint/dist/zip.zip' \
        SwiftLintBinary.artifactbundle/macos/swiftlint
fi

if test $all == 1 || test $xcodegen == 1; then
    # https://github.com/yonaskolb/XcodeGen/releases
    xcodegen_version=2.45.3
    lazy-download-zip-and-link-bin \
        xcodegen \
        https://github.com/yonaskolb/XcodeGen/releases/download/$xcodegen_version/xcodegen.artifactbundle.zip \
        '6a3cb84183c7fc88ebe0796af6a84bbf07b005bcdc61eaaef13a8a661d0675b8  .deps/xcodegen/dist/zip.zip' \
        xcodegen.artifactbundle/xcodegen-$xcodegen_version-macosx/bin/xcodegen
fi

if test $all == 1 || test $swiftformat == 1; then
    # https://github.com/nicklockwood/SwiftFormat/releases
    swiftformat_version=0.60.1
    lazy-download-zip-and-link-bin \
        swiftformat \
        https://github.com/nicklockwood/SwiftFormat/releases/download/$swiftformat_version/swiftformat.artifactbundle.zip \
        'cb4738085cf39c08da00b79b4a3683e77458ca12909934d04e5087d8e73f5e43  .deps/swiftformat/dist/zip.zip' \
        swiftformat.artifactbundle/swiftformat-$swiftformat_version-macos/bin/swiftformat
fi

if test $all == 1 || test $periphery == 1; then
    # https://github.com/peripheryapp/periphery/releases
    periphery_version=3.7.2
    lazy-download-zip-and-link-bin \
        periphery \
        https://github.com/peripheryapp/periphery/releases/download/$periphery_version/periphery-$periphery_version.zip \
        '3c1fa5214ffc3e7d184e898a4b96597b45f436982dd6e5e51295aaefa3cab601  .deps/periphery/dist/zip.zip' \
        periphery
fi
