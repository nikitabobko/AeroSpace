#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

build_version="0.0.0-SNAPSHOT"
codesign_identity="aerospace-codesign-certificate"
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-version)
            build_version="$2"
            shift
            shift
            ;;
        --codesign-identity)
            codesign_identity="$2"
            shift
            shift
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

generate-git-hash() {
cat > Sources/Common/gitHashGenerated.swift <<EOF
public let gitHash = "$(git rev-parse HEAD)"
public let gitShortHash = "$(git rev-parse --short HEAD)"
EOF
}

#############
### BUILD ###
#############

./build-docs.sh

./generate.sh
./script/check-uncommitted-files.sh
./generate.sh --build-version "$build_version" --codesign-identity "$codesign_identity"

generate-git-hash
swift build -c release --arch arm64 --arch x86_64
xcodebuild clean build \
    -scheme AeroSpace \
    -destination "generic/platform=macOS" \
    -configuration Release \
    -derivedDataPath .xcode-build

git checkout .

rm -rf .release && mkdir .release
cp -r .xcode-build/Build/Products/Release/AeroSpace.app .release
cp -r .build/apple/Products/Release/aerospace .release

################
### SIGN CLI ###
################

codesign -s "$codesign_identity" .release/aerospace

################
### VALIDATE ###
################

expected_layout=$(cat <<EOF
.release/AeroSpace.app
.release/AeroSpace.app/Contents
.release/AeroSpace.app/Contents/_CodeSignature
.release/AeroSpace.app/Contents/_CodeSignature/CodeResources
.release/AeroSpace.app/Contents/MacOS
.release/AeroSpace.app/Contents/MacOS/AeroSpace
.release/AeroSpace.app/Contents/Resources
.release/AeroSpace.app/Contents/Resources/default-config.toml
.release/AeroSpace.app/Contents/Resources/AppIcon.icns
.release/AeroSpace.app/Contents/Resources/Assets.car
.release/AeroSpace.app/Contents/Info.plist
.release/AeroSpace.app/Contents/PkgInfo
EOF
)

if [ "$expected_layout" != "$(find .release/AeroSpace.app)" ]; then
    echo "!!! Expect/Actual layout don't match !!!"
    find .release/AeroSpace.app
    exit 1
fi

check-universal-binary() {
    if ! file $1 | grep --fixed-string -q "Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64"; then
        echo "$1 is not a universal binary"
        exit 1
    fi
}

check-contains-hash() {
    hash=$(git rev-parse HEAD)
    if ! strings $1 | grep --fixed-string $hash > /dev/null; then
        echo "$1 doesn't contain $hash"
        exit 1
    fi
}

check-universal-binary .release/AeroSpace.app/Contents/MacOS/AeroSpace
check-universal-binary .release/aerospace

check-contains-hash .release/AeroSpace.app/Contents/MacOS/AeroSpace
check-contains-hash .release/aerospace

codesign -v .release/AeroSpace.app
codesign -v .release/aerospace

############
### PACK ###
############

mkdir -p .release/AeroSpace-v$build_version/manpage && cp .man/*.1 .release/AeroSpace-v$build_version/manpage
cd .release
    mkdir -p AeroSpace-v$build_version/bin && cp -r aerospace AeroSpace-v$build_version/bin
    cp -r AeroSpace.app AeroSpace-v$build_version
    zip -r AeroSpace-v$build_version.zip AeroSpace-v$build_version
cd -
