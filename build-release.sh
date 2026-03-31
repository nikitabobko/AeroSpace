#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

build_version="$(cat VERSION)"
codesign_identity="airlock-codesign-certificate"
while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        *) echo "Unknown option $1" > /dev/stderr; exit 1 ;;
    esac
done

#############
### BUILD ###
#############

./build-docs.sh
./build-shell-completion.sh

./generate.sh
./script/check-uncommitted-files.sh
./generate.sh --build-version "$build_version" --codesign-identity "$codesign_identity" --generate-git-hash

swift build -c release --arch arm64 --arch x86_64 --product airlock -Xswiftc -warnings-as-errors # CLI

# todo: make xcodebuild use the same toolchain as swift
# toolchain="$(plutil -extract CFBundleIdentifier raw ~/Library/Developer/Toolchains/swift-6.1-RELEASE.xctoolchain/Info.plist)"
# xcodebuild -toolchain "$toolchain" \
# Unfortunately, Xcode 16 fails with:
#     2025-05-05 15:51:15.618 xcodebuild[4633:13690815] Writing error result bundle to /var/folders/s1/17k6s3xd7nb5mv42nx0sd0800000gn/T/ResultBundle_2025-05-05_15-51-0015.xcresult
#     xcodebuild: error: Could not resolve package dependencies:
#       <unknown>:0: warning: legacy driver is now deprecated; consider avoiding specifying '-disallow-use-new-driver'
#     <unknown>:0: error: unable to execute command: <unknown>

rm -rf .release && mkdir .release

xcode_configuration="Release"
xcodebuild -version
xcodebuild-pretty .release/xcodebuild.log clean build \
    -scheme Airlock \
    -destination "generic/platform=macOS" \
    -configuration "$xcode_configuration" \
    -derivedDataPath .xcode-build

git checkout .

cp -r ".xcode-build/Build/Products/$xcode_configuration/Airlock.app" .release
cp -r .build/apple/Products/Release/airlock .release

################
### SIGN CLI ###
################

codesign -s "$codesign_identity" .release/airlock

################
### VALIDATE ###
################

expected_layout=$(cat <<EOF
.release/Airlock.app
.release/Airlock.app/Contents
.release/Airlock.app/Contents/_CodeSignature
.release/Airlock.app/Contents/_CodeSignature/CodeResources
.release/Airlock.app/Contents/MacOS
.release/Airlock.app/Contents/MacOS/Airlock
.release/Airlock.app/Contents/Resources
.release/Airlock.app/Contents/Resources/default-config.toml
.release/Airlock.app/Contents/Resources/AppIcon.icns
.release/Airlock.app/Contents/Resources/Assets.car
.release/Airlock.app/Contents/Info.plist
.release/Airlock.app/Contents/PkgInfo
EOF
)

if test "$expected_layout" != "$(find .release/Airlock.app)"; then
    echo "!!! Expect/Actual layout don't match !!!"
    find .release/Airlock.app
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

check-universal-binary .release/Airlock.app/Contents/MacOS/Airlock
check-universal-binary .release/airlock

check-contains-hash .release/Airlock.app/Contents/MacOS/Airlock
check-contains-hash .release/airlock

codesign -v .release/Airlock.app
codesign -v .release/airlock

############
### PACK ###
############

mkdir -p ".release/Airlock-v$build_version/manpage" && cp .man/*.1 ".release/Airlock-v$build_version/manpage"
cp -r ./legal ".release/Airlock-v$build_version/legal"
cp -r .shell-completion ".release/Airlock-v$build_version/shell-completion"
cd .release
    mkdir -p "Airlock-v$build_version/bin" && cp -r airlock "Airlock-v$build_version/bin"
    cp -r Airlock.app "Airlock-v$build_version"
    zip -r "Airlock-v$build_version.zip" "Airlock-v$build_version"
cd -

#################
### Brew Cask ###
#################
for cask_name in airlock airlock-dev; do
    ./script/build-brew-cask.sh \
        --cask-name "$cask_name" \
        --zip-uri ".release/Airlock-v$build_version.zip" \
        --build-version "$build_version"
done
