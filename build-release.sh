#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

build_version="0.0.0-SNAPSHOT"
app_name="FlightDeck"
cli_name="flightdeck"
team_id="${FLIGHTDECK_TEAM_ID:-2ZPA772V9V}"
codesign_identity="${DEVELOPER_ID_APPLICATION:-}"
notarize=0
notary_profile="${FLIGHTDECK_NOTARY_PROFILE:-view-md-notary}"
while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        --team-id) team_id="$2"; shift 2;;
        --notary-profile) notary_profile="$2"; shift 2;;
        --notarize) notarize=1; shift 1;;
        --skip-notarization) notarize=0; shift 1;;
        *) echo "Unknown option $1" > /dev/stderr; exit 1 ;;
    esac
done

if test -z "$codesign_identity"; then
    codesign_identity="Developer ID Application: Saad Bash ($team_id)"
fi

#############
### BUILD ###
#############

./build-docs.sh
./build-shell-completion.sh

./generate.sh
./script/check-uncommitted-files.sh
FLIGHTDECK_TEAM_ID="$team_id" ./generate.sh --build-version "$build_version" --codesign-identity "$codesign_identity" --generate-git-hash

swift build -c release --arch arm64 --arch x86_64 --product "$cli_name" -Xswiftc -warnings-as-errors # CLI

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
    -scheme "$app_name" \
    -destination "generic/platform=macOS" \
    -configuration "$xcode_configuration" \
    -derivedDataPath .xcode-build \
    DEVELOPMENT_TEAM="$team_id" \
    CODE_SIGN_IDENTITY="$codesign_identity"

FLIGHTDECK_TEAM_ID="$team_id" ./generate.sh --ignore-cmd-help --ignore-shell-parser

cp -r ".xcode-build/Build/Products/$xcode_configuration/$app_name.app" .release
cp -r ".build/apple/Products/Release/$cli_name" .release

############
### SIGN ###
############

codesign --force --deep --options runtime --timestamp -s "$codesign_identity" ".release/$app_name.app"
codesign --force --options runtime --timestamp -s "$codesign_identity" ".release/$cli_name"

################
### VALIDATE ###
################

for expected_file in \
    ".release/$app_name.app/Contents/_CodeSignature/CodeResources" \
    ".release/$app_name.app/Contents/MacOS/$app_name" \
    ".release/$app_name.app/Contents/Resources/default-config.toml" \
    ".release/$app_name.app/Contents/Resources/AppIcon.icns" \
    ".release/$app_name.app/Contents/Resources/Assets.car" \
    ".release/$app_name.app/Contents/Info.plist" \
    ".release/$app_name.app/Contents/PkgInfo"
do
    if ! test -e "$expected_file"; then
        echo "$expected_file is missing" > /dev/stderr
        exit 1
    fi
done

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

check-universal-binary ".release/$app_name.app/Contents/MacOS/$app_name"
check-universal-binary ".release/$cli_name"

check-contains-hash ".release/$app_name.app/Contents/MacOS/$app_name"
check-contains-hash ".release/$cli_name"

codesign -v --strict ".release/$app_name.app"
codesign -v --strict ".release/$cli_name"

################
### NOTARIZE ###
################

if test "$notarize" = 1; then
    notary_payload=".release/notary-payload"
    release_root="$app_name-v$build_version"
    notary_zip=".release/$release_root-notary.zip"

    rm -rf "$notary_payload" "$notary_zip"
    mkdir -p "$notary_payload/$release_root/bin"
    cp -r ".release/$app_name.app" "$notary_payload/$release_root"
    cp -r ".release/$cli_name" "$notary_payload/$release_root/bin"

    ditto -c -k --keepParent "$notary_payload/$release_root" "$notary_zip"
    xcrun notarytool submit "$notary_zip" --keychain-profile "$notary_profile" --wait

    xcrun stapler staple ".release/$app_name.app"
    xcrun stapler validate ".release/$app_name.app"
    spctl -a -vvv -t exec ".release/$app_name.app"
    spctl -a -vvv -t exec ".release/$cli_name"
fi

############
### PACK ###
############

release_root="$app_name-v$build_version"
rm -rf ".release/$release_root" ".release/$release_root.zip"
mkdir -p ".release/$release_root/manpage" && cp .man/*.1 ".release/$release_root/manpage"
cp -r ./legal ".release/$release_root/legal"
cp -r .shell-completion ".release/$release_root/shell-completion"
cd .release
    mkdir -p "$release_root/bin" && cp -r "$cli_name" "$release_root/bin"
    cp -r "$app_name.app" "$release_root"
    ditto -c -k --keepParent "$release_root" "$release_root.zip"
cd -

#################
### Brew Cask ###
#################
for cask_name in flightdeck flightdeck-dev; do
    ./script/build-brew-cask.sh \
        --cask-name "$cask_name" \
        --zip-uri ".release/$release_root.zip" \
        --build-version "$build_version"
done
