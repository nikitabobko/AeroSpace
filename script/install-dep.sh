#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

all=0
antlr=0
complgen=0
swiftlint=0
swiftformat=0
xcodegen=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --antlr) antlr=1; shift ;;
        --complgen) complgen=1; shift ;;
        --swiftlint) swiftlint=1; shift ;;
        --xcodegen) xcodegen=1; shift ;;
        --swiftformat) swiftformat=1; shift ;;
        --all) all=1; shift ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

check-version() {
    version="$1"; shift
    test -f "$1" && "$@" | grep --fixed-strings -q "$version"
}

if test $all == 1; then
    bundler install
fi

if test $all == 1 || test $antlr == 1; then
    if ! check-version 4.13.1 ./.deps/python-venv/bin/antlr4 -v 4.13.1; then
        python3 -m venv .deps/python-venv
        source .deps/python-venv/bin/activate
        python3 -m pip install 'antlr4-tools==0.2.1'
    fi
fi

if test $all == 1 || test $complgen == 1; then
    if ! check-version cacb3970eb ./.deps/cargo-root/bin/complgen version; then
        cargo install --git https://github.com/adaszko/complgen --rev cacb3970eb --root ./.deps/cargo-root
    fi
fi

download-zip-and-link-bin() {
    artifact_name=$1
    link=$2
    path_inside_zip=$3
    rm -rf ".deps/$artifact_name" && mkdir -p ".deps/$artifact_name/dist"
    curl -L "$link" -o ".deps/$artifact_name/dist/zip.zip"
    (cd "./.deps/$artifact_name/dist" && unzip zip.zip && rm -rf zip.zip)
    (cd "./.deps/$artifact_name" && ln -s "./dist/$path_inside_zip" "$artifact_name")
}

if test $all == 1 || test $swiftlint == 1; then
    swiftlint_version=0.56.2
    if ! check-version $swiftlint_version ./.deps/swiftlint/swiftlint --version; then
        download-zip-and-link-bin \
            swiftlint \
            https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/SwiftLintBinary-macos.artifactbundle.zip \
            SwiftLintBinary.artifactbundle/swiftlint-$swiftlint_version-macos/bin/swiftlint
    fi
fi

if test $all == 1 || test $xcodegen == 1; then
    xcodegen_version=2.42.0
    if ! check-version $xcodegen_version ./.deps/xcodegen/xcodegen --version; then
        download-zip-and-link-bin \
            xcodegen \
            https://github.com/yonaskolb/XcodeGen/releases/download/$xcodegen_version/xcodegen.artifactbundle.zip \
            xcodegen.artifactbundle/xcodegen-$xcodegen_version-macosx/bin/xcodegen
    fi
fi

if test $all == 1 || test $swiftformat == 1; then
    swiftformat_version=0.54.4
    if ! check-version $swiftformat_version ./.deps/swiftformat/swiftformat --version; then
        download-zip-and-link-bin \
            swiftformat \
            https://github.com/nicklockwood/SwiftFormat/releases/download/$swiftformat_version/swiftformat.artifactbundle.zip \
            swiftformat.artifactbundle/swiftformat-$swiftformat_version-macos/bin/swiftformat
    fi
fi
