#!/usr/bin/env bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

cd "$(dirname "$0")"

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

expected_layout=$(cat <<EOF
.release/AeroSpace.app
└── Contents
    ├── Info.plist
    ├── MacOS
    │   └── AeroSpace
    ├── PkgInfo
    ├── Resources
    │   ├── AppIcon.icns
    │   ├── Assets.car
    │   └── default-config.toml
    └── _CodeSignature
        └── CodeResources

5 directories, 7 files
EOF
)

if [ "$expected_layout" != "$(tree .release/AeroSpace.app)" ]; then
    echo "!!! Expect/Actual layout don't match !!!"
    tree .release/AeroSpace.app
    exit 1
fi

version=$(head -1 ./version.txt | awk '{print $1}')
mkdir -p .release/AeroSpace-v$version/manpage && cp .man/*.1 .release/AeroSpace-v$version/manpage
cd .release
    mkdir -p AeroSpace-v$version/bin && cp -r aerospace AeroSpace-v$version/bin
    cp -r AeroSpace.app AeroSpace-v$version
    zip -r AeroSpace-v${version}.zip AeroSpace-v$version
cd -
