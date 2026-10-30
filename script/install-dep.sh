#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

all=0
complgen=0
swiftlint=0
swiftformat=0
xcodegen=0
bundler=0
periphery=0
while test $# -gt 0; do
    case $1 in
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
    swiftlint_version=0.65.1
    lazy-download-zip-and-link-bin \
        swiftlint \
        https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/SwiftLintBinary.artifactbundle.zip \
        'c3a1d77647ca18c1b7e9be7dbc6cd4490d26422f28814b76370244ff61970869  .deps/swiftlint/dist/zip.zip' \
        SwiftLintBinary.artifactbundle/macos/swiftlint
fi

if test $all == 1 || test $xcodegen == 1; then
    # https://github.com/yonaskolb/XcodeGen/releases
    xcodegen_version=2.46.0
    lazy-download-zip-and-link-bin \
        xcodegen \
        https://github.com/yonaskolb/XcodeGen/releases/download/$xcodegen_version/xcodegen.artifactbundle.zip \
        'ef6d0a23bfb7393387f98e321ffd78a487231172e2e78c48d3c26275c263fd0c  .deps/xcodegen/dist/zip.zip' \
        xcodegen.artifactbundle/xcodegen-$xcodegen_version-macosx/bin/xcodegen
fi

if test $all == 1 || test $swiftformat == 1; then
    # https://github.com/nicklockwood/SwiftFormat/releases
    swiftformat_version=0.64.4
    lazy-download-zip-and-link-bin \
        swiftformat \
        https://github.com/nicklockwood/SwiftFormat/releases/download/$swiftformat_version/swiftformat.artifactbundle.zip \
        'c2ba19f5f70a1aba089f836ada7960268ec9a68671d61059fec1a565afb50836  .deps/swiftformat/dist/zip.zip' \
        swiftformat.artifactbundle/swiftformat-$swiftformat_version-macos/bin/swiftformat
fi

if test $all == 1 || test $periphery == 1; then
    # https://github.com/nikitabobko/periphery/releases
    periphery_version=1.0.0
    lazy-download-zip-and-link-bin \
        periphery \
        https://github.com/nikitabobko/periphery/releases/download/v$periphery_version/periphery-arm-v$periphery_version.zip \
        '28ef394d85c0b7edc76b9060f519cc03742c865c4a922a2e8efe27344e5e2132  .deps/periphery/dist/zip.zip' \
        periphery
fi
