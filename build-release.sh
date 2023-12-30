#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

check-clean-git-working-dir() {
    if [ ! -z "$(git status --porcelain)" ]; then
        echo "git working directory must be clean"
        exit 1
    fi
}

generate-git-hash() {
cat > LocalPackage/Sources/Common/gitHashGenerated.swift <<EOF
public let gitHash = "$(git rev-parse HEAD)"
public let gitShortHash = "$(git rev-parse --short HEAD)"
EOF
}

#############
### BUILD ###
#############

./build-docs.sh

./generate.sh
check-clean-git-working-dir

generate-git-hash
xcodebuild -scheme AeroSpace build -configuration Release
cd LocalPackage
    rm -rf .build
    swift build -c release --arch arm64 --arch x86_64
cd - > /dev/null
git checkout LocalPackage/Sources/Common/gitHashGenerated.swift

rm -rf .release && mkdir .release
cd ~/Library/Developer/Xcode/DerivedData
    if [ "$(ls | grep AeroSpace | wc -l)" -ne 1 ]; then
        echo "Found several AeroSpace dirs in $(pwd)"
        ls | grep AeroSpace
        exit 1
    fi
cd - > /dev/null
cp -r ~/Library/Developer/Xcode/DerivedData/AeroSpace*/Build/Products/Release/AeroSpace.app .release
cp -r LocalPackage/.build/apple/Products/Release/aerospace .release

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

############
### PACK ###
############

version=$(head -1 ./version.txt | awk '{print $1}')
mkdir -p .release/AeroSpace-v$version/manpage && cp .man/*.1 .release/AeroSpace-v$version/manpage
cd .release
    mkdir -p AeroSpace-v$version/bin && cp -r aerospace AeroSpace-v$version/bin
    cp -r AeroSpace.app AeroSpace-v$version
    zip -r AeroSpace-v${version}.zip AeroSpace-v$version
cd -
