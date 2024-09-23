#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

build_version="0.0.0-SNAPSHOT"
codesign_identity="aerospace-codesign-certificate"
configuration="Release"
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        --configuration) configuration="$2"; shift 2;;
        *) echo "Unknown option $1" > /dev/stderr; exit 1 ;;
    esac
done

case $configuration in
    Release)
        aerospace_dot_app='AeroSpace.app'
        aerospace_dot_app_bin='AeroSpace'
        cask_name='aerospace'
        ;;
    Dev)
        aerospace_dot_app='AeroSpace-Dev.app'
        aerospace_dot_app_bin='AeroSpace-Dev'
        cask_name='aerospace-dev'
        ;;
    *) echo "Unknown configuration: $configuration" > /dev/stderr; exit 1;;
esac

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
./build-shell-completion.sh

./generate.sh
./script/check-uncommitted-files.sh
./generate.sh --build-version "$build_version" --codesign-identity "$codesign_identity"

generate-git-hash
swift build -c release --arch arm64 --arch x86_64 --product aerospace # CLI
xcodebuild clean build \
    -scheme AeroSpace \
    -destination "generic/platform=macOS" \
    -configuration "$configuration" \
    -derivedDataPath .xcode-build

git checkout .

rm -rf .release && mkdir .release
cp -r ".xcode-build/Build/Products/$configuration/$aerospace_dot_app" .release
cp -r .build/apple/Products/Release/aerospace .release

################
### SIGN CLI ###
################

codesign -s "$codesign_identity" .release/aerospace

################
### VALIDATE ###
################

expected_layout=$(cat <<EOF
.release/$aerospace_dot_app
.release/$aerospace_dot_app/Contents
.release/$aerospace_dot_app/Contents/_CodeSignature
.release/$aerospace_dot_app/Contents/_CodeSignature/CodeResources
.release/$aerospace_dot_app/Contents/MacOS
.release/$aerospace_dot_app/Contents/MacOS/$aerospace_dot_app_bin
.release/$aerospace_dot_app/Contents/Resources
.release/$aerospace_dot_app/Contents/Resources/default-config.toml
.release/$aerospace_dot_app/Contents/Resources/AppIcon.icns
.release/$aerospace_dot_app/Contents/Resources/Assets.car
.release/$aerospace_dot_app/Contents/Info.plist
.release/$aerospace_dot_app/Contents/PkgInfo
EOF
)

if [ "$expected_layout" != "$(find .release/$aerospace_dot_app)" ]; then
    echo "!!! Expect/Actual layout don't match !!!"
    find .release/$aerospace_dot_app
    exit 1
fi

check-universal-binary() {
    if ! file "$1" | grep --fixed-string -q "Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64"; then
        echo "$1 is not a universal binary"
        exit 1
    fi
}

check-contains-hash() {
    hash=$(git rev-parse HEAD)
    if ! strings "$1" | grep --fixed-string "$hash" > /dev/null; then
        echo "$1 doesn't contain $hash"
        exit 1
    fi
}

check-universal-binary .release/$aerospace_dot_app/Contents/MacOS/$aerospace_dot_app_bin
check-universal-binary .release/aerospace

check-contains-hash .release/$aerospace_dot_app/Contents/MacOS/$aerospace_dot_app_bin
check-contains-hash .release/aerospace

codesign -v .release/$aerospace_dot_app
codesign -v .release/aerospace

############
### PACK ###
############

mkdir -p ".release/AeroSpace-v$build_version/manpage" && cp .man/*.1 ".release/AeroSpace-v$build_version/manpage"
cp -r ./legal ".release/AeroSpace-v$build_version/legal"
cp -r .shell-completion ".release/AeroSpace-v$build_version/shell-completion"
cd .release
    mkdir -p "AeroSpace-v$build_version/bin" && cp -r aerospace "AeroSpace-v$build_version/bin"
    cp -r $aerospace_dot_app "AeroSpace-v$build_version"
    zip -r "AeroSpace-v$build_version.zip" "AeroSpace-v$build_version"
cd -

#################
### Brew Cask ###
#################
./script/build-brew-cask.sh \
    --cask-name "$cask_name" \
    --zip-uri ".release/AeroSpace-v$build_version.zip" \
    --build-version "$build_version"
