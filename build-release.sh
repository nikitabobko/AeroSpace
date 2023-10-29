#!/usr/bin/env bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

cd "$(dirname "$0")"

checkCleanGitWorkingDir() {
    if [ ! -z "$(git status --porcelain)" ]; then
        echo "git working directory must be clean"
        exit 1
    fi
}

generateGitHash() {
cat > src/gitHashGenerated.swift <<-EOF
public let gitHash = "$(git rev-parse HEAD)"
public let gitShortHash = "$(git rev-parse --short HEAD)"
EOF
}

xcodegen # https://github.com/yonaskolb/XcodeGen
checkCleanGitWorkingDir
generateGitHash
xcodebuild -scheme AeroSpace build -configuration Release

git checkout src/gitHashGenerated.swift

rm -rf .build && mkdir .build
pushd ~/Library/Developer/Xcode/DerivedData > /dev/null
    if [ "$(ls | grep AeroSpace | wc -l)" -ne 1 ]; then
        echo "Found several AeroSpace dirs in $(pwd)"
        ls | grep AeroSpace
        exit 1
    fi
popd > /dev/null
cp -r ~/Library/Developer/Xcode/DerivedData/AeroSpace*/Build/Products/Release/AeroSpace.app .build

expected_layout=$(cat <<EOF
.build/AeroSpace.app
└── Contents
    ├── Info.plist
    ├── MacOS
    │   └── AeroSpace
    ├── PkgInfo
    ├── Resources
    │   └── default-config.toml
    └── _CodeSignature
        └── CodeResources

5 directories, 5 files
EOF
)

if [ "$expected_layout" != "$(tree .build/AeroSpace.app)" ]; then
    echo "!!! Expect/Actual layout don't match !!!"
    tree .build/AeroSpace.app
    exit 1
fi

VERSION=$(grep MARKETING_VERSION project.yml | awk '{print $2}')
pushd .build
    zip -r AeroSpace-v${VERSION}.zip AeroSpace.app
popd
