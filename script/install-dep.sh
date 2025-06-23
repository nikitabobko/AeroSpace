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

check-version() {
    version="$1"; shift
    test -f "$1" && "$@" | grep --fixed-strings -q "$version"
}

if test $all == 1 || test $bundler == 1; then
    bundler install
fi

if test $all == 1 || test $antlr == 1; then
    # https://github.com/antlr/antlr4/releases
    if ! check-version 4.13.1 ./.deps/python-venv/bin/antlr4 -v 4.13.1; then
        python3 -m venv .deps/python-venv
        source .deps/python-venv/bin/activate
        python3 -m pip install 'antlr4-tools==0.2.1'
    fi
fi

if test $all == 1 || test $complgen == 1; then
    # https://github.com/adaszko/complgen/releases
    if ! check-version cacb3970eb ./.deps/cargo-root/bin/complgen version; then
        cargo install --git https://github.com/adaszko/complgen --rev cacb3970eb --root ./.deps/cargo-root
    fi
fi

lazy-download-zip-and-link-bin() {
    artifact_name=$1
    version=$2
    link=$3
    sha=$4
    path_inside_zip=$5

    root_path=".deps/$artifact_name"
    marker_path="$root_path/$version.marker"
    root_dist_path="$root_path/dist"
    zip_name="zip.zip"
    zip_path="$root_dist_path/$zip_name"

    if ! test -f "$marker_path"; then
        rm -rf "$root_path" && mkdir -p "$root_dist_path"
        curl -L "$link" -o "$zip_path"
        (cd "$root_dist_path" && unzip "$zip_name")
        (cd "$root_path" && ln -s "./dist/$path_inside_zip" "$artifact_name")

        diff --color <(echo "$sha") <(shasum -a 256 "$zip_path")
        touch "$marker_path"
    fi
}

if test $all == 1 || test $swiftlint == 1; then
    # https://github.com/realm/SwiftLint/releases
    swiftlint_version=0.59.1
    lazy-download-zip-and-link-bin \
        swiftlint \
        $swiftlint_version \
        https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/SwiftLintBinary.artifactbundle.zip \
        'b9f915a58a818afcc66846740d272d5e73f37baf874e7809ff6f246ea98ad8a2  .deps/swiftlint/dist/zip.zip' \
        SwiftLintBinary.artifactbundle/swiftlint-$swiftlint_version-macos/bin/swiftlint
fi

if test $all == 1 || test $xcodegen == 1; then
    # https://github.com/yonaskolb/XcodeGen/releases
    xcodegen_version=2.43.0
    lazy-download-zip-and-link-bin \
        xcodegen \
        $xcodegen_version \
        https://github.com/yonaskolb/XcodeGen/releases/download/$xcodegen_version/xcodegen.artifactbundle.zip \
        'b08135558e9e061440c148a91cc07142a534e99dd8a17bc050a3d30a5b5d340d  .deps/xcodegen/dist/zip.zip' \
        xcodegen.artifactbundle/xcodegen-$xcodegen_version-macosx/bin/xcodegen
fi

if test $all == 1 || test $swiftformat == 1; then
    # https://github.com/nicklockwood/SwiftFormat/releases
    swiftformat_version=0.56.4
    lazy-download-zip-and-link-bin \
        swiftformat \
        $swiftformat_version \
        https://github.com/nicklockwood/SwiftFormat/releases/download/$swiftformat_version/swiftformat.artifactbundle.zip \
        '8b9c5ce7e3172b7d6f3d5c450495e8fbc5f60e2b80e03dff215cfff36f35425b  .deps/swiftformat/dist/zip.zip' \
        swiftformat.artifactbundle/swiftformat-$swiftformat_version-macos/bin/swiftformat
fi
